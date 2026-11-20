import pytest

from reference.patterns.factory import Circle, ShapeFactory, Square, Triangle


def test_circle_creation():
    """Circle の生成テスト"""
    shape = ShapeFactory.create_shape("circle")
    assert isinstance(shape, Circle)
    assert shape.draw() == "Drawing a Circle"


def test_square_creation():
    """Square の生成テスト"""
    shape = ShapeFactory.create_shape("square")
    assert isinstance(shape, Square)
    assert shape.draw() == "Drawing a Square"


def test_triangle_creation():
    """Triangle の生成テスト"""
    shape = ShapeFactory.create_shape("triangle")
    assert isinstance(shape, Triangle)
    assert shape.draw() == "Drawing a Triangle"


def test_unknown_shape_creation():
    """未知の Shape タイプの生成テスト"""
    with pytest.raises(ValueError) as excinfo:
        ShapeFactory.create_shape("hexagon")
    assert str(excinfo.value) == "Unknown shape type: hexagon"
