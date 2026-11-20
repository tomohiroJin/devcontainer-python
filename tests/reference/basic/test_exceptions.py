# **テストコード**
import pytest

import reference.basic.exceptions as ex


def test_divide():
    """基本的な例外処理を確認する"""
    assert ex.divide(10, 2) == 5, "10 / 2 の結果が正しくありません。"
    with pytest.raises(ValueError):
        ex.divide(10, 0)


def test_parse_int():
    """例外の種類を確認する"""
    assert ex.parse_int("123") == 123, "整数変換が正しくありません。"
    with pytest.raises(ValueError):
        ex.parse_int("abc")


def test_custom_error():
    """カスタム例外の動作を確認する"""
    result = ex.process_data("hello")
    assert result == "HELLO", "文字列処理の結果が正しくありません。"
    result = ex.process_data(123)
    assert result == "Error: Data must be a string.", (
        "カスタム例外のエラーメッセージが正しくありません。"
    )
