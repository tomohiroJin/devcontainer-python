"""日本語の名前を、テストでもコードでも使えることを確かめる回帰テスト。

このファイルは、ファイル名・クラス名・関数名・引数名・変数名に日本語を使って
います。lint の規則が日本語の名前を違反と判定するようになると、`make lint` と
コミット前フックがこのファイルで失敗します（Ruff の `N` を外した理由は
README の「Ruff のルール」を参照）。
"""

import pytest


class 計算機:
    def 足す(self, 左辺: int, 右辺: int) -> int:
        合計 = 左辺 + 右辺
        return 合計


def フィズバズ(数: int) -> str:
    if 数 % 15 == 0:
        return "FizzBuzz"
    if 数 % 3 == 0:
        return "Fizz"
    if 数 % 5 == 0:
        return "Buzz"
    return str(数)


def test_1と2を足すと3になる() -> None:
    assert 計算機().足す(1, 2) == 3


class Test計算機:
    def test_足し算は順序を入れ替えても同じ結果になる(self) -> None:
        電卓 = 計算機()
        assert 電卓.足す(2, 3) == 電卓.足す(3, 2)


@pytest.mark.parametrize(
    ("数", "期待値"),
    [(1, "1"), (3, "Fizz"), (5, "Buzz"), (15, "FizzBuzz")],
)
def test_フィズバズは倍数に応じた文字列を返す(数: int, 期待値: str) -> None:
    assert フィズバズ(数) == 期待値
