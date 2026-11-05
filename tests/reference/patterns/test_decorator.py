from reference.patterns.decorator import (
    BaseNotifier,
    DecoratedNotifier,
    exclamation_decorator,
    greet,
    uppercase_decorator,
)


def test_uppercase_decorator():
    """uppercase_decorator のテスト"""

    @uppercase_decorator
    def sample():
        return "hello"

    assert sample() == "HELLO"


def test_exclamation_decorator():
    """exclamation_decorator のテスト"""

    @exclamation_decorator
    def sample():
        return "wow"

    assert sample() == "wow!"


def test_combined_decorator():
    """複数のデコレータを組み合わせたテスト"""
    result = greet("Alice")
    assert result == "HELLO, ALICE!"


def test_class_decorator():
    """クラスに適用したデコレータのテスト"""
    notifier = BaseNotifier()
    decorated_notifier = DecoratedNotifier(notifier)

    assert notifier.send("Normal message") == "Normal message"
    assert decorated_notifier.send("Normal message") == "[IMPORTANT] Normal message"
