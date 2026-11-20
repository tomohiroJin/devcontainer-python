"""
Observer パターンは、オブジェクト間の1対多の依存関係を構築するために使用されます。
このパターンでは、1つのオブジェクト（Subject）の状態が変化した際に、
その変更を依存している他のオブジェクト（Observers）に通知します。

このファイルでは、Observer パターンを Python で実装し、テストコードを含めています。
"""

from typing import Protocol


# **Observer インターフェース**
class Observer(Protocol):
    """
    Observer（監視者）のインターフェース。
    """

    def update(self, message: str):
        pass


# **Subject クラス**
class Subject:
    """
    状態を監視する対象（Subject）。
    """

    def __init__(self):
        self._observers: list[Observer] = []

    def add_observer(self, observer: Observer):
        self._observers.append(observer)

    def remove_observer(self, observer: Observer):
        self._observers.remove(observer)

    def notify_observers(self, message: str):
        for observer in self._observers:
            observer.update(message)


# **具体的な Observer クラス**
class ConcreteObserverA:
    """
    Observerの具体的な実装例A。
    """

    def __init__(self):
        self.messages: list[str] = []

    def update(self, message: str):
        self.messages.append(f"ObserverA received: {message}")


class ConcreteObserverB:
    """
    Observerの具体的な実装例B。
    """

    def __init__(self):
        self.messages: list[str] = []

    def update(self, message: str):
        self.messages.append(f"ObserverB received: {message}")
