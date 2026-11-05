"""
Strategy パターンは、アルゴリズムをカプセル化し、
必要に応じて実行時に切り替え可能にするデザインパターンです。
このファイルでは、Strategy パターンを Python で実装し、テストコードを含めています。
"""

from typing import Protocol


# **Strategy インターフェース**
class PaymentStrategy(Protocol):
    """
    支払い方法のインターフェース。
    """

    def pay(self, amount: float) -> str:
        pass


# **具体的な Strategy クラス**
class CreditCardPayment:
    """
    クレジットカードでの支払いを実装するクラス。
    """

    def __init__(self, card_number: str, card_holder: str):
        self.card_number = card_number
        self.card_holder = card_holder

    def pay(self, amount: float) -> str:
        return f"Paid {amount} using Credit Card ({self.card_holder})."


class PayPalPayment:
    """
    PayPalでの支払いを実装するクラス。
    """

    def __init__(self, email: str):
        self.email = email

    def pay(self, amount: float) -> str:
        return f"Paid {amount} using PayPal ({self.email})."


# **Context クラス**
class PaymentContext:
    """
    支払い方法を動的に設定するコンテキストクラス。
    """

    def __init__(self, strategy: PaymentStrategy):
        self.strategy = strategy

    def set_strategy(self, strategy: PaymentStrategy):
        self.strategy = strategy

    def execute_payment(self, amount: float) -> str:
        return self.strategy.pay(amount)
