# Single entry point for everyday tasks. The README, the VS Code tasks and the
# Python checks in CI all call these targets, so a check behaves the same
# everywhere.
.DEFAULT_GOAL := help

PYTHON ?= python
IMAGE ?= devcontainer-python:local
# Tools that are not part of the image are installed on demand into ignored
# virtual environments. Bump the versions here.
PIP_AUDIT_VERSION ?= 2.10.1
PIP_TOOLS_VERSION ?= 7.7.0
AUDIT_VENV ?= .venv-audit
LOCK_VENV ?= .venv-lock

.PHONY: help test watch lint fmt typecheck cov check pre-commit hooks unhooks post-create \
	doctor audit audit-container lock clean

help: ## このヘルプを表示
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z_-]+:.*## / \
		{printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

test: ## テストを実行（pytest と scripts/ の単体テスト）
	$(PYTHON) -m pytest
	$(PYTHON) -m unittest discover -s scripts -p 'test_*.py'

watch: ## ファイルを保存するたびに pytest を再実行（Ctrl+C で終了）
	ptw .

lint: ## lint と整形の確認（ファイルは変更しない）
	ruff check .
	ruff format --check .

fmt: ## 自動修正と整形（ファイルを書き換える）
	ruff check --fix .
	ruff format .

typecheck: ## mypy で型チェック
	mypy

cov: ## カバレッジ付きでテスト（端末表示・coverage.xml・htmlcov/）
	$(PYTHON) -m pytest --cov --cov-report=term-missing --cov-report=xml \
		--cov-report=html

check: lint typecheck test ## lint・型チェック・テストをまとめて実行

pre-commit: ## コミット前フックを全ファイルに実行（CI と同じ）
	prek run --all-files

hooks: ## コミット前フックを Git に登録（Git リポジトリでなければ何もしない）
	@sh scripts/git-hooks/install.sh install

unhooks: ## コミット前フックの登録を外す
	@sh scripts/git-hooks/install.sh uninstall

# Run by the Dev Container when it is created (postCreateCommand). A failure
# must not stop the container from starting, so it only says what to do. The
# message lives here, not in devcontainer.json: VS Code shows the command
# itself in its log, where the text of a failure reads like a failure.
post-create: ## Dev Container の作成時の処理（コミット前フックの登録）
	@echo '[準備] コミット前の検査を登録します（git commit のたびに、整形・lint・型チェックを自動で実行する仕組みです）。'
	@if sh scripts/git-hooks/install.sh install; then \
		echo '[準備] 完了しました。問題はありません。make doctor で、開発を始められる状態かを確認できます。'; \
	else \
		echo '[準備] コミット前の検査を登録できませんでした。開発は続けられますが、コミットのときの自動の検査が動きません。'; \
		echo '[準備] 上に表示された原因を直してから、ターミナルで make hooks を実行してください。'; \
	fi

doctor: ## 開発を始められる状態かを確認（make doctor ARGS=--quiet で問題だけを表示）
	@bash scripts/doctor.sh $(ARGS)

$(AUDIT_VENV)/.pip-audit-$(PIP_AUDIT_VERSION):
	rm -rf $(AUDIT_VENV)
	$(PYTHON) -m venv $(AUDIT_VENV)
	$(AUDIT_VENV)/bin/python -m pip install --quiet pip-audit==$(PIP_AUDIT_VERSION)
	touch $@

audit: $(AUDIT_VENV)/.pip-audit-$(PIP_AUDIT_VERSION) ## Python 依存の脆弱性監査（pip-audit、要ネットワーク）
	$(AUDIT_VENV)/bin/pip-audit --strict --no-deps --disable-pip \
		-r requirements-bootstrap.txt -r requirements.txt \
		--format json --output pip-audit.json

audit-container: ## イメージをビルドして Trivy で監査（ホスト側で実行。docker と trivy が必要）
	docker build --pull -f .devcontainer/Dockerfile -t $(IMAGE) .
	trivy image --scanners vuln --severity HIGH,CRITICAL --format json \
		--output trivy.json $(IMAGE)
	python3 scripts/check_container_audit.py trivy.json \
		security/container-baseline.json

$(LOCK_VENV)/.pip-tools-$(PIP_TOOLS_VERSION):
	rm -rf $(LOCK_VENV)
	$(PYTHON) -m venv $(LOCK_VENV)
	$(LOCK_VENV)/bin/python -m pip install --quiet pip-tools==$(PIP_TOOLS_VERSION)
	touch $@

lock: $(LOCK_VENV)/.pip-tools-$(PIP_TOOLS_VERSION) ## requirements.in から requirements.txt を再生成（要ネットワーク）
	$(LOCK_VENV)/bin/pip-compile --upgrade --generate-hashes --strip-extras \
		--no-emit-index-url --no-emit-trusted-host requirements.in

clean: ## キャッシュと生成物を削除
	rm -rf .pytest_cache .mypy_cache .ruff_cache .coverage coverage.xml htmlcov \
		pip-audit.json trivy.json $(AUDIT_VENV) $(LOCK_VENV)
	find . -type d -name __pycache__ -prune -exec rm -rf {} +
