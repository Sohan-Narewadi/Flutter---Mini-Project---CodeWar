import time

import pytest
from starlette.websockets import WebSocketDisconnect

from app.models import Friend, Player, Question, RoomResult
from app.rooms import manager as mgr


@pytest.fixture(autouse=True)
def fast_rooms(monkeypatch):
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    monkeypatch.setattr(mgr, "COUNTDOWN_S", 0.2)
    monkeypatch.setattr(mgr, "TICK_S", 0.05)
    monkeypatch.setattr(mgr, "GRACE_S", 0.4)


def token_of(headers):
    return headers["Authorization"].split(" ", 1)[1]


def create_room(client, headers, **body):
    body.setdefault("mode", "race")
    body.setdefault("difficulty", "easy")
    r = client.post("/api/rooms", json=body, headers=headers)
    assert r.status_code == 201, r.text
    return r.json()


def drain_until(ws, wanted, limit=40):
    """Receives messages until one satisfies `wanted(msg)`; returns it."""
    seen = []
    for _ in range(limit):
        msg = ws.receive_json()
        seen.append(msg)
        if wanted(msg):
            return msg
    raise AssertionError(f"never saw wanted message; saw {[m.get('type') for m in seen]}")


def snapshot_with(ws, status):
    return drain_until(ws, lambda m: m["type"] == "snapshot" and m["room"]["status"] == status)["room"]


def reference_code(client, question):
    db = client.SessionLocal()
    code = db.query(Question).filter(Question.id == question["id"]).first().reference_solution
    db.close()
    return code


# ---- REST ---------------------------------------------------------------

def test_create_room_returns_code_and_snapshot(client, make_player):
    _, h = make_player("host")
    snap = create_room(client, h, mode="duel", difficulty="medium")
    assert len(snap["code"]) == 6 and not set(snap["code"]) & set("01OIL")
    assert snap["status"] == "lobby" and snap["mode"] == "duel" and snap["max_players"] == 2
    assert [p["name"] for p in snap["players"]] == ["host"] and snap["players"][0]["is_host"]


def test_create_room_validation_and_auth(client, make_player):
    _, h = make_player("host")
    assert client.post("/api/rooms", json={"mode": "royale"}, headers=h).status_code == 422
    assert client.post("/api/rooms", json={"difficulty": "nope"}, headers=h).status_code == 422
    assert client.post("/api/rooms", json={"language": "cobol"}, headers=h).status_code == 422
    assert client.post("/api/rooms", json={}).status_code == 401


def test_join_get_and_errors(client, make_player):
    _, ha = make_player("alpha")
    _, hb = make_player("bravo")
    _, hc = make_player("charlie")
    code = create_room(client, ha, mode="duel")["code"]
    joined = client.post(f"/api/rooms/{code.lower()}/join", headers=hb)
    assert joined.status_code == 200 and len(joined.json()["players"]) == 2
    assert client.post(f"/api/rooms/{code}/join", headers=hb).status_code == 200  # idempotent
    assert client.post(f"/api/rooms/{code}/join", headers=hc).status_code == 409  # duel is full
    assert client.get(f"/api/rooms/{code}", headers=hc).json()["code"] == code
    assert client.post("/api/rooms/ZZZZZZ/join", headers=hb).status_code == 404
    assert client.get("/api/rooms/ZZZZZZ", headers=hb).status_code == 404


# ---- WebSocket ------------------------------------------------------------

def test_ws_rejects_bad_token_and_unknown_room(client, make_player):
    _, h = make_player("host")
    code = create_room(client, h)["code"]
    with client.websocket_connect(f"/ws/rooms/{code}?token=bogus") as ws:
        with pytest.raises(WebSocketDisconnect) as e:
            ws.receive_json()
        assert e.value.code == 4401
    with client.websocket_connect(f"/ws/rooms/NOPE12?token={token_of(h)}") as ws:
        with pytest.raises(WebSocketDisconnect) as e:
            ws.receive_json()
        assert e.value.code == 4404


def test_lobby_roster_updates_when_friend_connects(client, make_player):
    _, ha = make_player("alpha")
    _, hb = make_player("bravo")
    code = create_room(client, ha)["code"]
    with client.websocket_connect(f"/ws/rooms/{code}?token={token_of(ha)}") as wa:
        first = snapshot_with(wa, "lobby")
        assert first["players"][0]["connected"] is True
        with client.websocket_connect(f"/ws/rooms/{code}?token={token_of(hb)}") as wb:
            snap = drain_until(wa, lambda m: m["type"] == "snapshot" and len(m["room"]["players"]) == 2)["room"]
            assert {p["name"] for p in snap["players"]} == {"alpha", "bravo"}
        # bravo leaves the lobby: removed from the roster
        snap = drain_until(wa, lambda m: m["type"] == "snapshot" and len(m["room"]["players"]) == 1)["room"]
        assert snap["players"][0]["name"] == "alpha"


def test_non_host_cannot_start_and_host_needs_a_second_player(client, make_player):
    _, ha = make_player("alpha")
    _, hb = make_player("bravo")
    code = create_room(client, ha)["code"]
    with client.websocket_connect(f"/ws/rooms/{code}?token={token_of(ha)}") as wa:
        snapshot_with(wa, "lobby")
        wa.send_json({"type": "start"})
        err = drain_until(wa, lambda m: m["type"] == "error")
        assert err["code"] == "need_players"
        with client.websocket_connect(f"/ws/rooms/{code}?token={token_of(hb)}") as wb:
            snapshot_with(wb, "lobby")
            wb.send_json({"type": "start"})
            assert drain_until(wb, lambda m: m["type"] == "error")["code"] == "not_host"


def test_full_race_winner_gets_rating_xp_and_friendship(client, make_player):
    ida, ha = make_player("alpha")
    idb, hb = make_player("bravo")
    code = create_room(client, ha, difficulty="easy")["code"]
    with client.websocket_connect(f"/ws/rooms/{code}?token={token_of(ha)}") as wa, \
         client.websocket_connect(f"/ws/rooms/{code}?token={token_of(hb)}") as wb:
        wa.send_json({"type": "start"})
        q = drain_until(wa, lambda m: m["type"] == "question")["question"]
        drain_until(wb, lambda m: m["type"] == "question")
        assert "judge_cases" not in q and "reference_solution" not in q and q["starter_code"]["python"]

        # alpha submits garbage: scored but not a win
        wa.send_json({"type": "submit", "code": "def nothing():\n    return None\n", "language": "python"})
        res = drain_until(wa, lambda m: m["type"] == "run_result")
        assert res["correctness_percent"] < 100
        snap = drain_until(wb, lambda m: m["type"] == "snapshot" and any(
            p["name"] == "alpha" and p["submissions"] == 1 for p in m["room"]["players"]))["room"]
        assert snap["status"] == "running"

        # bravo solves it
        wb.send_json({"type": "submit", "code": reference_code(client, q), "language": "python"})
        done = snapshot_with(wa, "finished")
        if not done.get("standings") or "rating_delta" not in done["standings"][0]:
            done = drain_until(wa, lambda m: m["type"] == "snapshot" and m["room"]["status"] == "finished"
                               and "rating_delta" in (m["room"]["standings"] or [{}])[0])["room"]
        assert done["reason"] == "solved"
        st = done["standings"]
        assert [s["name"] for s in st] == ["bravo", "alpha"] and [s["rank"] for s in st] == [1, 2]
        assert st[0]["rating_delta"] == 16 and st[1]["rating_delta"] == -16
        assert st[0]["xp"] == 30 and st[1]["xp"] == 0

    db = client.SessionLocal()
    a, b = db.query(Player).filter(Player.id == ida).first(), db.query(Player).filter(Player.id == idb).first()
    assert (b.rating, a.rating) == (1016, 984)
    assert (b.wins, b.losses, a.wins, a.losses) == (1, 0, 0, 1)
    assert b.xp == 30 and b.gold == 7
    assert db.query(RoomResult).filter(RoomResult.room_code == code).count() == 2
    assert db.query(Friend).filter(Friend.player_id == ida, Friend.friend_id == idb).first() is not None
    assert db.query(Friend).filter(Friend.player_id == idb, Friend.friend_id == ida).first() is not None
    db.close()


def test_run_is_private_and_unscored(client, make_player):
    _, ha = make_player("alpha")
    _, hb = make_player("bravo")
    code = create_room(client, ha)["code"]
    with client.websocket_connect(f"/ws/rooms/{code}?token={token_of(ha)}") as wa, \
         client.websocket_connect(f"/ws/rooms/{code}?token={token_of(hb)}") as wb:
        wa.send_json({"type": "start"})
        q = drain_until(wa, lambda m: m["type"] == "question")["question"]
        drain_until(wb, lambda m: m["type"] == "question")
        wa.send_json({"type": "run", "code": reference_code(client, q), "language": "python"})
        res = drain_until(wa, lambda m: m["type"] == "run_result")
        assert res["kind"] == "run" and res["correctness_percent"] == 100
        wb.send_json({"type": "ping"})
        assert drain_until(wb, lambda m: m["type"] == "pong")
        wb.send_json({"type": "submit", "code": "def nothing():\n    return None\n"})
        snap = drain_until(wb, lambda m: m["type"] == "snapshot" and m["room"]["status"] == "running"
                           and any(p["name"] == "bravo" and p["submissions"] == 1 for p in m["room"]["players"]))["room"]
        # the room is still running: alpha's private run did not win it
        assert snap["status"] == "running"
        assert next(p for p in snap["players"] if p["name"] == "alpha")["submissions"] == 0


def test_late_joiner_cannot_enter_a_running_room(client, make_player):
    _, ha = make_player("alpha")
    _, hb = make_player("bravo")
    _, hc = make_player("charlie")
    code = create_room(client, ha)["code"]
    with client.websocket_connect(f"/ws/rooms/{code}?token={token_of(ha)}") as wa, \
         client.websocket_connect(f"/ws/rooms/{code}?token={token_of(hb)}") as wb:
        wa.send_json({"type": "start"})
        drain_until(wa, lambda m: m["type"] == "question")
        assert client.post(f"/api/rooms/{code}/join", headers=hc).status_code == 409
        with client.websocket_connect(f"/ws/rooms/{code}?token={token_of(hc)}") as wc:
            err = wc.receive_json()
            assert err["type"] == "error" and err["code"] == "started"
            with pytest.raises(WebSocketDisconnect) as e:
                wc.receive_json()
            assert e.value.code == 4403


def test_player_who_drops_past_grace_forfeits_and_opponent_wins(client, make_player):
    ida, ha = make_player("alpha")
    idb, hb = make_player("bravo")
    code = create_room(client, ha)["code"]
    with client.websocket_connect(f"/ws/rooms/{code}?token={token_of(ha)}") as wa:
        with client.websocket_connect(f"/ws/rooms/{code}?token={token_of(hb)}") as wb:
            wa.send_json({"type": "start"})
            drain_until(wa, lambda m: m["type"] == "question")
            drain_until(wb, lambda m: m["type"] == "question")
        # bravo's socket is closed; after the grace period alpha wins by forfeit
        done = drain_until(wa, lambda m: m["type"] == "snapshot" and m["room"]["status"] == "finished"
                           and "rating_delta" in (m["room"]["standings"] or [{}])[0], limit=200)["room"]
        assert done["reason"] == "forfeit"
        assert done["standings"][0]["name"] == "alpha"
        assert done["standings"][1]["forfeited"] is True
    db = client.SessionLocal()
    assert db.query(Player).filter(Player.id == ida).first().wins == 1
    assert db.query(Player).filter(Player.id == idb).first().losses == 1
    db.close()


def test_reconnect_within_grace_keeps_the_seat(client, make_player, monkeypatch):
    monkeypatch.setattr(mgr, "GRACE_S", 5.0)
    _, ha = make_player("alpha")
    _, hb = make_player("bravo")
    code = create_room(client, ha)["code"]
    with client.websocket_connect(f"/ws/rooms/{code}?token={token_of(ha)}") as wa:
        with client.websocket_connect(f"/ws/rooms/{code}?token={token_of(hb)}") as wb:
            wa.send_json({"type": "start"})
            q = drain_until(wa, lambda m: m["type"] == "question")["question"]
            drain_until(wb, lambda m: m["type"] == "question")
        with client.websocket_connect(f"/ws/rooms/{code}?token={token_of(hb)}") as wb2:
            # the question is re-sent so the player can keep working
            again = drain_until(wb2, lambda m: m["type"] == "question")["question"]
            assert again["id"] == q["id"]
            snap = drain_until(wa, lambda m: m["type"] == "snapshot" and all(p["connected"] for p in m["room"]["players"]))["room"]
            assert snap["status"] == "running" and not any(p["forfeited"] for p in snap["players"])


def test_judge_rejects_unsupported_language_and_oversized_code(client, make_player):
    _, ha = make_player("alpha")
    _, hb = make_player("bravo")
    code = create_room(client, ha)["code"]
    with client.websocket_connect(f"/ws/rooms/{code}?token={token_of(ha)}") as wa, \
         client.websocket_connect(f"/ws/rooms/{code}?token={token_of(hb)}") as wb:
        wa.send_json({"type": "start"})
        drain_until(wa, lambda m: m["type"] == "question")
        wa.send_json({"type": "submit", "code": "x", "language": "cobol"})
        assert drain_until(wa, lambda m: m["type"] == "error")["code"] == "bad_language"
        wa.send_json({"type": "submit", "code": "x" * 30000, "language": "python"})
        assert drain_until(wa, lambda m: m["type"] == "error")["code"] == "too_long"
        wa.send_json({"type": "submit"})
        assert drain_until(wa, lambda m: m["type"] == "error")["code"] == "bad_message"
        wa.send_json({"type": "dance"})
        assert drain_until(wa, lambda m: m["type"] == "error")["code"] == "bad_message"


def test_submit_before_start_is_rejected(client, make_player):
    _, ha = make_player("alpha")
    code = create_room(client, ha)["code"]
    with client.websocket_connect(f"/ws/rooms/{code}?token={token_of(ha)}") as wa:
        snapshot_with(wa, "lobby")
        wa.send_json({"type": "submit", "code": "x", "language": "python"})
        assert drain_until(wa, lambda m: m["type"] == "error")["code"] == "not_running"
