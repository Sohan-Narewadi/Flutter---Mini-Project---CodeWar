import pytest

from app.rooms.engine import Room, RoomError

T0 = 1000.0


def make(mode="race", **kw):
    return Room("ABC123", mode, "easy", "python", host_id=1, host_name="host", now=T0, **kw)


def running_room(mode="race", extra=(2,)):
    r = make(mode)
    for pid in extra:
        r.join(pid, f"p{pid}", T0)
    r.start(1, T0)
    r.tick(T0 + 3)
    assert r.status == "running"
    return r


def test_new_room_has_host_in_lobby():
    r = make()
    assert r.status == "lobby" and r.host_id == 1
    assert [m.player_id for m in r.members.values()] == [1]


def test_join_is_idempotent_and_capped():
    r = make()
    assert r.join(2, "b", T0) is True
    assert r.join(2, "b", T0) is False
    for pid in range(3, 9):
        r.join(pid, f"p{pid}", T0)
    assert len(r.members) == 8
    with pytest.raises(RoomError) as e:
        r.join(9, "late", T0)
    assert e.value.code == "full"


def test_duel_allows_only_two_players():
    r = make("duel")
    r.join(2, "b", T0)
    with pytest.raises(RoomError) as e:
        r.join(3, "c", T0)
    assert e.value.code == "full"


def test_start_requires_host_and_two_players():
    r = make()
    with pytest.raises(RoomError) as e:
        r.start(1, T0)
    assert e.value.code == "need_players"
    r.join(2, "b", T0)
    with pytest.raises(RoomError) as e:
        r.start(2, T0)
    assert e.value.code == "not_host"
    r.start(1, T0)
    assert r.status == "countdown"
    with pytest.raises(RoomError) as e:
        r.start(1, T0)
    assert e.value.code == "started"


def test_countdown_becomes_running_after_delay():
    r = make()
    r.join(2, "b", T0)
    r.start(1, T0)
    assert r.tick(T0 + 1) == [] and r.status == "countdown"
    assert r.tick(T0 + 3) == ["running"]
    assert r.status == "running" and r.started_at == T0 + 3


def test_late_joiner_rejected_but_member_can_rejoin():
    r = running_room()
    with pytest.raises(RoomError) as e:
        r.join(9, "late", T0 + 5)
    assert e.value.code == "started"
    assert r.join(2, "p2", T0 + 5) is False  # existing member reconnecting


def test_lobby_leave_removes_member_and_transfers_host():
    r = make()
    r.join(2, "b", T0 + 1)
    r.join(3, "c", T0 + 2)
    r.leave(1, T0 + 3)
    assert r.host_id == 2 and 1 not in r.members
    r.leave(2, T0 + 4)
    r.leave(3, T0 + 5)
    assert r.closed is True


def test_submit_tracks_best_and_never_decreases():
    r = running_room()
    r.submit(2, 1, 4, T0 + 10)
    r.submit(2, 3, 4, T0 + 20)
    r.submit(2, 2, 4, T0 + 30)
    m = r.members[2]
    assert m.best_pct == 75 and m.best_at == T0 + 20 and m.submissions == 3
    assert r.status == "running"


def test_full_solve_finishes_and_winner_is_first():
    r = running_room()
    r.submit(2, 2, 4, T0 + 10)
    r.submit(1, 4, 4, T0 + 40)
    assert r.status == "finished" and r.finish_reason == "solved"
    st = r.standings()
    assert [s["player_id"] for s in st] == [1, 2]
    assert [s["rank"] for s in st] == [1, 2]


def test_submit_outside_running_rejected():
    r = make()
    r.join(2, "b", T0)
    with pytest.raises(RoomError) as e:
        r.submit(1, 1, 1, T0)
    assert e.value.code == "not_running"
    r = running_room()
    r.submit(1, 4, 4, T0 + 5)
    with pytest.raises(RoomError):
        r.submit(2, 1, 4, T0 + 6)  # room already finished


def test_non_member_cannot_submit():
    r = running_room()
    with pytest.raises(RoomError) as e:
        r.submit(99, 1, 1, T0 + 5)
    assert e.value.code == "not_member"


def test_timeout_ranks_by_percent_then_time():
    r = running_room(extra=(2, 3))
    r.submit(2, 2, 4, T0 + 10)   # 50% at +10
    r.submit(3, 2, 4, T0 + 20)   # 50% at +20 (later)
    r.submit(1, 3, 4, T0 + 50)   # 75%
    limit = r.time_limit_s
    assert r.tick(T0 + 3 + limit) == ["finished"]
    assert r.finish_reason == "timeout"
    assert [s["player_id"] for s in r.standings()] == [1, 2, 3]


def test_equal_score_and_time_share_a_rank():
    r = running_room(extra=(2, 3))
    r.submit(2, 2, 4, T0 + 10)
    r.submit(3, 2, 4, T0 + 10)
    r.tick(T0 + 3 + r.time_limit_s)
    ranks = {s["player_id"]: s["rank"] for s in r.standings()}
    assert ranks[2] == ranks[3] == 1 and ranks[1] == 3


def test_nobody_scored_is_a_shared_rank():
    r = running_room()
    r.tick(T0 + 3 + r.time_limit_s)
    assert {s["rank"] for s in r.standings()} == {1}


def test_disconnect_within_grace_can_reconnect():
    r = running_room()
    r.disconnect(2, T0 + 10)
    r.tick(T0 + 30)
    assert r.members[2].forfeited is False and r.status == "running"
    r.reconnect(2)
    r.tick(T0 + 100)
    assert r.members[2].forfeited is False


def test_disconnect_past_grace_forfeits_and_ends_two_player_room():
    r = running_room()
    r.disconnect(2, T0 + 10)
    assert r.tick(T0 + 10 + 31) == ["finished"]
    assert r.members[2].forfeited is True
    assert r.finish_reason == "forfeit"
    assert [s["player_id"] for s in r.standings()] == [1, 2]


def test_forfeit_in_bigger_room_keeps_game_going():
    r = running_room(extra=(2, 3))
    r.disconnect(3, T0 + 5)
    r.tick(T0 + 40)
    assert r.members[3].forfeited is True and r.status == "running"
    r.submit(1, 4, 4, T0 + 50)
    assert r.standings()[-1]["player_id"] == 3  # forfeiter is last


def test_forfeited_player_cannot_submit():
    r = running_room(extra=(2, 3))
    r.disconnect(3, T0 + 5)
    r.tick(T0 + 40)
    with pytest.raises(RoomError):
        r.submit(3, 4, 4, T0 + 41)


def test_snapshot_contains_public_fields_only():
    r = running_room()
    r.submit(2, 1, 4, T0 + 10)
    snap = r.snapshot(T0 + 20)
    assert snap["code"] == "ABC123" and snap["status"] == "running" and snap["mode"] == "race"
    assert snap["seconds_left"] == r.time_limit_s - 17
    p2 = next(p for p in snap["players"] if p["player_id"] == 2)
    assert p2["best_pct"] == 25 and p2["passed"] == 1 and p2["total"] == 4
    assert "code" not in p2 and "token" not in str(snap)
    assert snap["standings"] is None


def test_snapshot_after_finish_has_standings():
    r = running_room()
    r.submit(1, 4, 4, T0 + 10)
    snap = r.snapshot(T0 + 11)
    assert snap["status"] == "finished" and snap["reason"] == "solved"
    assert snap["standings"][0]["player_id"] == 1


def test_zero_total_submission_counts_as_zero_percent():
    r = running_room()
    r.submit(2, 0, 0, T0 + 5)
    assert r.members[2].best_pct == 0
