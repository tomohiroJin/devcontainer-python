import pytest


class Station:
    def get_timetable(self, line, direction):
        if line.name == YAMANOTESEN.name:
            return ['13:00', '13:05']
        return ['12:00']


class Line:
    def __init__(self, name):
        self.name = name

YAMANOTESEN = Line('山手線')
CHUOSEN = Line('中央線')


class Train:
    def __init__(self, direction, timetable):
        self.timetable = timetable

    def get_timetable(self, line, direction):
        pass

    def get_departure_time(self, station):
#        return [tm for st, tm in self.timetable if st == station][0]
        for st, tm in self.timetable:
            if st == station:
                return tm


def test_新宿から中央線で下りで出発する時刻がわかる():
    # Arrange
    shinjuku = Station()

    # Act
    actual = shinjuku.get_timetable(line=CHUOSEN, direction='下り')

    # Assert
    assert actual == ['12:00']


def test_新宿から山手線で内回りで出発する時刻がわかる():
    # Arrange
    shinjuku = Station()

    # Act
    actual = shinjuku.get_timetable(line=YAMANOTESEN, direction='内回り')

    # Assert
    assert actual == ['13:00', '13:05']



class Test_電車が中野に何時に到着するかわかる:
    def test_新宿1200発中野1205発(self):
        # Arrange
        train = Train(direction='下り', timetable=[('新宿', '12:00'), ('中野','12:05')])

        # Act
        actual = train.get_departure_time(station='中野')

        # Assert
        assert actual == '12:05'

    def test_新宿1200発経由しない駅(self):
        # Arrange
        train = Train(direction='下り', timetable=[('新宿', '12:00'), ('中野','12:05')])

        # Act

        # Assert
        with pytest.raises(ValueError):
            train.get_departure_time(station='京都')
