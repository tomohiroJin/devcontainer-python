array = [1, 2, 3]


def test_array():
    assert array == [1, 2, 3]


def test_summary():
    assert sum(array) == 6


def test_average():
    assert sum(array) / len(array) == 2
