from app.rooms.rating import update_ratings


def test_winner_gains_and_loser_loses_equal_amounts_when_ratings_equal():
    d = update_ratings([(1, 1000, 1), (2, 1000, 2)])
    assert d[1] == 16 and d[2] == -16


def test_upset_gives_bigger_swing():
    d = update_ratings([(1, 800, 1), (2, 1200, 2)])
    assert d[1] > 16 and d[2] < -16


def test_favorite_winning_gains_little():
    d = update_ratings([(1, 1400, 1), (2, 1000, 2)])
    assert 0 < d[1] < 8 and d[2] == -d[1]


def test_tie_between_equal_players_changes_nothing():
    d = update_ratings([(1, 1000, 1), (2, 1000, 1)])
    assert d == {1: 0, 2: 0}


def test_everyone_tied_for_first_means_no_change():
    d = update_ratings([(1, 1000, 1), (2, 1000, 1), (3, 1000, 1)])
    assert d == {1: 0, 2: 0, 3: 0}


def test_multiplayer_is_zero_sum_ish_and_ordered():
    d = update_ratings([(1, 1000, 1), (2, 1000, 2), (3, 1000, 3), (4, 1000, 4)])
    assert d[1] > d[2] > d[3] > d[4]
    assert abs(sum(d.values())) <= 2  # rounding only


def test_single_player_unchanged():
    assert update_ratings([(1, 1000, 1)]) == {1: 0}
