# モブプログラミング・ペアプログラミングの手順

この Dev Container を使って、複数人で TDD を行うときの手順です。初めて参加する人が、この文書だけで準備を終えられることを目指しています。

- 決めたことの経緯は、[Issue #18](https://github.com/tomohiroJin/devcontainer-python/issues/18) と、その親の [Issue #13](https://github.com/tomohiroJin/devcontainer-python/issues/13) にあります。
- 確かめたことと、確かめていないことは、末尾の「この文書の検証」にあります。

## 方式: ホストの Dev Container を、Live Share で共有する

**ホスト（1人）だけが Dev Container を開き、ほかの人（ゲスト）は VS Code の Live Share で参加します。**

| 役割 | 準備するもの | すること |
| --- | --- | --- |
| ホスト | Docker、VS Code、Dev Containers の拡張、Live Share の拡張、このリポジトリへの push の権限 | Dev Container を開く。Live Share を始める。**テストの実行、整形、コミット、push は、すべてホストの Dev Container で行う** |
| ゲスト | VS Code と Live Share の拡張（ブラウザーでも参加できます） | 招待のリンクから参加する。コードを書く、読む、指示を出す |

この方式にした理由は、次のとおりです。

- **ゲストの準備が、ほぼ要りません。** Docker も、リポジトリの clone も、push の権限も要りません。
- **道具が1つにそろいます。** テスト、lint、整形、コミット前の検査は、すべてホストのコンテナにある、同じ版の道具で動きます。前回のモブ（2026-11-20）でつまずいた、整形のずれ、コミットの失敗、push の失敗は、どれも「人によって環境が違う」ことが原因でした。操作する場所を1か所に決めることで、起きなくなります。

### 守ること

1. **コミットと push は、ホストが、Dev Container のターミナルで行います。** ゲストは行いません。
2. **テストは、ホストの `make watch` で回します。** そのターミナルを、ゲストにも見えるように共有します。
3. **コミットの前の整形は、ホストのコンテナに任せます。** ゲストのエディターの設定で整形がずれても、コミット前の検査（`make pre-commit` と同じもの）が、コミットのときに直すか、止めます。
4. **ホストを交代する場合は、push してから交代します**（下の「ホストを交代する」）。

### ほかの方式

人数や目的によっては、次の方式も使えます。

| 方式 | 向いている場合 | 注意 |
| --- | --- | --- |
| 各自が自分の Dev Container を開き、Git で交代する | 全員が、自分の手元でテストやデバッグを動かしたい。全員に Docker と push の権限がある | 交代のたびに、push と pull が必要です。全員が、始める前に `make doctor` と、push の確認を済ませておきます |
| 各自が GitHub Codespaces を開き、Git で交代する | 手元に Docker を入れられない人がいる | このリポジトリは、Codespaces での動作をまだ確かめていません（[Issue #19](https://github.com/tomohiroJin/devcontainer-python/issues/19)）。無料枠の範囲に注意が要ります |

## 始める前に

### ホスト（10分。前日までに済ませておくと安心です）

1. リポジトリを clone し、VS Code で開いて、「コンテナーで再度開く」を選びます（[README「はじめに」](../README.md#はじめに)）。
2. **Dev Container の中にいることを確かめます。** VS Code の左下に「開発コンテナー: Python DevContainer」と表示されます。ターミナルのプロンプトは `vscode` で始まります。
3. VS Code の統合ターミナルで、環境を確かめます。

   ```bash
   make doctor
   ```

   `FAIL` が出たら、表示された直し方に従って直します。前回のモブでは、Git の名前とメールアドレス、push の認証でつまずきました。どちらも、ここで分かります。
4. テストが動くことを確かめます。

   ```bash
   make check
   ```

5. **push できることを、実際に確かめます。** `make doctor` は、認証の手段があることまでを確かめます。リモートには接続しません。モブ用のブランチを作って push するのが、いちばん確実です。

   ```bash
   git switch -c mob/2026-12-01-fizzbuzz
   git push -u origin mob/2026-12-01-fizzbuzz
   ```

   main には、直接 push できません（プルリクエストと CI の成功が必要です）。モブの作業は、ブランチで行います。
6. Live Share の拡張（`ms-vsliveshare.vsliveshare`）を入れ、サインインしておきます。

### ゲスト（5分）

1. VS Code に、Live Share の拡張（`ms-vsliveshare.vsliveshare`）を入れます。VS Code を入れられない場合は、招待のリンクをブラウザーで開いても参加できます。
2. コミットに名前を残したい場合は、名前とメールアドレスをホストに伝えます（下の「共同作業者を記録する」）。

ゲストは、リポジトリの clone も、Docker も、`make doctor` も要りません。

### ゲストにおすすめの設定

ゲストが入力した内容は、ホストのファイルに保存されます。次の設定にしておくと、ゲストの入力で見た目がずれることが減ります。必須ではありません（ずれても、コミットの前にホストのコンテナが直します）。

- インデントは、スペース4つ（VS Code の右下の表示で確かめられます）。
- ゲスト側の、Python 用の整形の拡張（Black、autopep8 など）が、保存時に動かないようにする。動く場合は、モブの間だけ無効にします。

## 進め方

### 1. ホストが、セッションを始める

1. Dev Container を開いた VS Code で、Live Share を始めます（左下の「Live Share」、またはコマンドパレットの「Live Share: Start Collaboration Session」）。
2. 招待のリンクを、ゲストに伝えます。
3. テストを回すターミナルを開きます。

   ```bash
   make watch
   ```

   起動時に一度テストを実行し、そのあとは、`*.py` のファイルが保存されるたびに再実行します。Ctrl+C で終了します。
4. そのターミナルを、ゲストに共有します（コマンドパレットの「Live Share: Share Terminal」。**読み取り専用**をおすすめします）。ゲストの画面にも、テストの結果が表示されます。

   読み書きできるターミナルを共有すると、ゲストが、ホストのコンテナでコマンドを実行できます。ホストの認証情報で push することもできるため、信頼できる相手とだけにしてください。

### 2. 題材のファイルを作る

題材（kata）ごとに、`src/` と `tests/` に同じ名前のディレクトリを作ります。次は、題材が FizzBuzz の場合の例です。

```bash
mkdir -p src/kata tests/kata
touch src/kata/__init__.py tests/kata/__init__.py
```

テストから書き始めます（`tests/kata/test_fizzbuzz.py`）。

```python
from kata.fizzbuzz import fizzbuzz


def test_3の倍数はFizzになる() -> None:
    assert fizzbuzz(3) == "Fizz"
```

保存すると、`make watch` のターミナルが失敗（Red）を表示します。`src/kata/fizzbuzz.py` がまだないためです。

```python
def fizzbuzz(数: int) -> str:
    if 数 % 3 == 0:
        return "Fizz"
    return str(数)
```

保存すると、成功（Green）に変わります。

- **日本語の名前を使えます。** テストの名前、関数、引数、変数に日本語を使っても、lint とコミット前の検査は通ります（[README「Ruff のルール」](../README.md#ruff-のルール)）。テストの関数名は、`test_` で始めます。
- `src/` の直下のディレクトリが、そのまま import の名前になります（上の例では `kata`）。

### 3. Red → Green → Refactor を回す

1. **Red**: 失敗するテストを1つ書いて、保存します。`make watch` が失敗を表示することを、全員で確かめます。
2. **Green**: テストが通る最小のコードを書いて、保存します。
3. **Refactor**: テストが通ったまま、コードを整えます。
4. 区切りのよいところで、ホストがコミットします（次の節）。

役割は、**ドライバー**（キーボードを操作する人）と、**ナビゲーター**（次に何をするかを言葉で伝える人たち）です。ドライバーは、ゲストでもかまいません。時間（5〜10分）を決めて、交代します。交代のときに、コミットしておくと、どこまで進んだかが残ります。

### 4. コミットする（ホスト）

ホストが、Dev Container のターミナルで行います。

```bash
git add -A
git commit
```

コミットのたびに、コミット前の検査（行末の空白、Ruff、mypy など）が動きます。

- **検査がファイルを直した場合**は、コミットが止まります。直された内容を確かめて、もう一度 `git add -A` と `git commit` を実行します。
- **直せない問題（lint の違反、型のエラー）が表示された場合**は、その場で直すか、`make fmt` と `make check` で内容を確かめます。

### 5. 共同作業者を記録する

コミットメッセージの末尾に、空行を1つ置いて、参加した人を `Co-authored-by:` で書きます。GitHub は、この行を読んで、コミットに全員を表示します。

```text
3の倍数で Fizz を返す

Co-authored-by: 山田 花子 <hanako@example.com>
Co-authored-by: Taro Suzuki <12345678+taro@users.noreply.github.com>
```

- **メールアドレスは、その人の GitHub のアカウントに登録されているものを使います。** 違うアドレスだと、GitHub のアカウントと結び付きません。
- メールアドレスを公開したくない人は、GitHub の「noreply」のアドレスを使います（GitHub の Settings → Emails に表示される、`数字+ユーザー名@users.noreply.github.com` の形のアドレス）。
- 参加者の行は、セッションの最初に、テキストファイルなどにまとめておくと、コミットのたびに貼り付けられます。`git commit` を引数なしで実行すると、エディター（ターミナルでは nano）が開くので、そこに貼ります。nano は、Ctrl+O と Enter で保存し、Ctrl+X で終了します。

コマンドだけで書く場合は、`-m` を2回使います（2つ目が、空行のあとの段落になります）。

```bash
git commit -m "3の倍数で Fizz を返す" -m "Co-authored-by: 山田 花子 <hanako@example.com>"
```

### 6. push する（ホスト）

```bash
git push
```

モブが終わったら、ブランチからプルリクエストを作ります。CI（`ci-ok`）が成功すると、マージできます。練習だけが目的で、main に入れない場合は、ブランチを残すか、消すかを決めます。

### ホストを交代する

ホスト（Dev Container を開いている人）を交代する場合は、次の順で行います。

1. 今のホストが、コミットして push します。Live Share を終了します。
2. 次のホストが、自分の Dev Container で、同じブランチを取得します。

   ```bash
   git fetch origin
   git switch mob/2026-12-01-fizzbuzz
   git pull
   ```

3. 次のホストが、Live Share を始めて、新しいリンクを伝えます。

次のホストも、「始める前に」のホストの準備（`make doctor` と、push の確認）を済ませておく必要があります。

## うまくいかないとき

| 起きること | 原因と対処 |
| --- | --- |
| コミットしようとすると、名前とメールアドレスを聞かれる、または失敗する | Git の名前とメールアドレスが、コンテナに届いていません。`make doctor` が、設定のコマンドを表示します |
| push すると、認証に失敗する | `make doctor` を実行し、「リモートと認証」の表示に従います。多くの場合は、`gh auth login` と `gh auth setup-git` で直ります（[README「GitHub CLI で認証する」](../README.md#github-cli-で認証する)） |
| main に push すると、拒否される | main は、プルリクエストと CI の成功が必要です。ブランチを作って push します |
| コミットが、「files were modified by this hook」で止まる | コミット前の検査が、ファイルを直しました。`git add -A` のあと、もう一度コミットします |
| コミットしたのに、検査が動いた様子がない | ホスト（Dev Container の外）のターミナルでコミットしています。「Dev Container の外（ホスト）なので…」と表示されます。VS Code の左下の表示を確かめて、Dev Container のターミナルで操作します |
| `make watch` が、保存しても再実行しない | 監視するのは、`*.py` のファイルです。リポジトリのルートで起動しているか、ファイルが保存されているか（ゲストの入力は、保存するまでホストのファイルに反映されません）を確かめます |
| テストが、`ModuleNotFoundError` で失敗する | `src/` の下のディレクトリの名前と、import の名前が合っているかを確かめます。上の例では、`src/kata/fizzbuzz.py` を `from kata.fizzbuzz import ...` で読みます |
| `make doctor` で、ツールの版が違うと表示される | 古いイメージで作ったコンテナです。コマンドパレットの「Dev Containers: Rebuild Container」で作り直します |
| 整形が、人によってずれる | コミットの前に、ホストのコンテナで `make fmt` を実行します。コミット前の検査も、同じ整形を行います |

ここにない問題は、`make doctor` の出力を添えて、Issue（「環境の不具合」のテンプレート）で知らせてください。出力は、メールアドレスやトークンを伏せて表示しますが、貼る前に目を通してください。

## この文書の検証

### 確かめたこと（2026-11-22。Dockerfile と同じ手順でビルドしたイメージで実行）

- 「題材のファイルを作る」の手順のとおりにファイルを作ると、テストが、コードを書く前は失敗し、書いたあとは成功する。日本語の名前を使ったファイルで、`make check` と、コミット前の検査が通る。
- 「共同作業者を記録する」の `git commit -m ... -m ...` の形で、`Co-authored-by:` が、Git のトレーラーとして記録される（日本語の名前を含む）。
- `make watch` が、保存のたびに再実行すること（[docs/mob-feedback-validation.md](mob-feedback-validation.md)）。
- `make doctor` が、名前とメールアドレスがない状態と、認証の手段がない状態を、`FAIL` で知らせること（[docs/doctor-validation.md](doctor-validation.md)）。リポジトリの所有者が、実際の Dev Container でも確かめています。
- main への直接の変更が止められること（[docs/ci-security-policy.md](ci-security-policy.md)）。

### 確かめていないこと

- **Live Share の動き。** この検証環境では、VS Code も Live Share も動かせません。ターミナルの共有、ゲストの入力がホストのファイルに保存される動き、ゲスト側の整形の拡張の影響は、Live Share の一般的な動きとして書いています。「守ること」は、これらの動きに頼らなくても成り立つように（整形とコミットをホストのコンテナに寄せる形で）決めています。
- **この文書だけで、初めての人が準備を終えられること。** 実際のモブで確かめる必要があります。分かりにくかった箇所は、Issue #18 に記録してください。
- **GitHub が、`Co-authored-by:` の行から、コミットに共同作業者を表示すること。** Git に記録されることまでを確かめました。GitHub の画面では確かめていません。
- **VS Code のテストエクスプローラーの表示**（テストの件数、日本語のテスト名）。
- **ほかの方式**（各自の Dev Container、Codespaces）での進行。
