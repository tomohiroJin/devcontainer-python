# **テストコード**
import reference.basic.functions as func


def test_greet():
    """基本的な関数の動作を確認する"""
    assert func.greet("Alice") == "Hello, Alice!", "挨拶メッセージが正しくありません。"


def test_power():
    """デフォルト引数を利用したべき乗計算を確認する"""
    assert func.power(3) == 9, "デフォルト引数を利用した計算が正しくありません。"
    assert func.power(2, 3) == 8, "指定された指数を利用した計算が正しくありません。"


def test_divide():
    """位置引数とキーワード専用引数を確認する"""
    assert func.divide(10, 3) == 3.33, "デフォルトの精度が正しくありません。"
    assert func.divide(10, 3, precision=1) == 3.3, "指定された精度が正しくありません。"


def test_sum_all():
    """可変長引数の合計計算を確認する"""
    assert func.sum_all(1, 2, 3, 4) == 10, "可変長引数の合計が正しくありません。"
    assert func.sum_all() == 0, "引数なしの合計が正しくありません。"


def test_describe_person():
    """キーワード引数を利用した説明文生成を確認する"""
    description = func.describe_person("Alice", age=30, job="Engineer")
    assert description == "Name: Alice, age: 30, job: Engineer", (
        "説明文生成が正しくありません。"
    )


def test_lambda():
    """ラムダ関数の動作を確認する"""
    assert func.multiply(2, 3) == 6, "ラムダ関数の結果が正しくありません。"


def test_make_multiplier():
    """ネスト関数による関数生成を確認する"""
    doubler = func.make_multiplier(2)
    tripler = func.make_multiplier(3)
    assert doubler(5) == 10, "doubler関数の結果が正しくありません。"
    assert tripler(4) == 12, "tripler関数の結果が正しくありません。"


def test_factorial():
    """再帰関数の動作を確認する"""
    assert func.factorial(5) == 120, "階乗計算の結果が正しくありません。"
    assert func.factorial(0) == 1, "0の階乗の結果が正しくありません。"
