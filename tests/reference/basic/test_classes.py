# **テストコード**
from reference.basic.classes import Counter, Employee, Person, Vector


def test_person():
    """Personクラスの基本的な動作を確認する"""
    person = Person("Alice", 30)
    assert person.name == "Alice", "名前が正しくありません。"
    assert person.age == 30, "年齢が正しくありません。"
    assert person.introduce() == "My name is Alice and I am 30 years old.", (
        "自己紹介が正しくありません。"
    )


def test_counter():
    """Counterクラスのクラス変数とインスタンス変数を確認する"""
    counter1 = Counter()
    counter2 = Counter()
    counter1.increment()
    counter2.increment()
    counter2.increment()
    assert counter1.instance_count == 1, "インスタンスカウントが正しくありません。"
    assert counter2.instance_count == 2, "インスタンスカウントが正しくありません。"
    assert Counter.total_count == 3, "クラス全体のカウントが正しくありません。"


def test_employee():
    """Employeeクラスの継承と動作を確認する"""
    employee = Employee("Bob", 25, "Engineer")
    assert employee.name == "Bob", "名前が正しくありません。"
    assert employee.age == 25, "年齢が正しくありません。"
    assert employee.job_title == "Engineer", "職位が正しくありません。"
    assert (
        employee.introduce()
        == "My name is Bob, I am 25 years old, and I work as a Engineer."
    ), "自己紹介が正しくありません。"


def test_vector():
    """Vectorクラスの特殊メソッドを確認する"""
    v1 = Vector(1, 2)
    v2 = Vector(3, 4)
    v3 = v1 + v2
    assert str(v3) == "Vector(4, 6)", "ベクトルの加算結果が正しくありません。"
    assert str(v1) == "Vector(1, 2)", "ベクトルの文字列表現が正しくありません。"
