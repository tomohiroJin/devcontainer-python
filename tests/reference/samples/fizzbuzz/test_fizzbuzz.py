import pytest

from reference.samples.fizzbuzz.fizzbuzz import fizzbuzz


@pytest.mark.parametrize(
    "input, expected",
    [
        pytest.param(1, "1", id="Returns '1' when input is 1"),
        pytest.param(2, "2", id="Returns '2' when input is 2"),
        pytest.param(3, "Fizz", id="Returns 'Fizz' when input is 3"),
        pytest.param(5, "Buzz", id="Returns 'Buzz' when input is 5"),
        pytest.param(15, "FizzBuzz", id="Returns 'FizzBuzz' when input is 15"),
    ],
)
def test_fizzbuzz(input, expected):
    """FizzBuzz function test"""
    assert fizzbuzz(input) == expected
