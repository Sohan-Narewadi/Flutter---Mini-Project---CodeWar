from datetime import datetime, timedelta

from app.models import Player, PlayerBadge, RoomResult


def _result(db, code, pid, rank, **kw):
    db.add(RoomResult(room_code=code, mode=kw.pop("mode", "race"), player_id=pid, rank=rank, **kw))


def test_matches_empty_for_new_player(auth_client):
    assert auth_client.get("/api/matches").json() == []


def test_matches_newest_first_with_opponents_and_deltas(client, make_player):
    pa, ha = make_player("alpha")
    pb, _ = make_player("bravo")
    pc, _ = make_player("carol")
    now = datetime(2026, 10, 1, 12, 0, 0)
    db = client.SessionLocal()
    _result(db, "OLD111", pa, 2, rating_before=1000, rating_delta=-12, xp=5, gold=1, best_pct=50, finished_at=now)
    _result(db, "OLD111", pb, 1, finished_at=now)
    _result(db, "NEW222", pa, 1, mode="duel", rating_before=988, rating_delta=15, xp=30, gold=7, best_pct=100,
            finished_at=now + timedelta(hours=1))
    _result(db, "NEW222", pc, 2, mode="duel", finished_at=now + timedelta(hours=1))
    db.commit()
    db.close()
    rows = client.get("/api/matches", headers=ha).json()
    assert [r["room_code"] for r in rows] == ["NEW222", "OLD111"]
    first = rows[0]
    assert first["mode"] == "duel" and first["rank"] == 1 and first["players_count"] == 2
    assert first["rating_delta"] == 15 and first["xp"] == 30 and first["best_pct"] == 100
    assert first["opponents"] == ["carol".title()] or first["opponents"] == ["carol"]
    assert first["finished_at"].startswith("2026-10-01T13:00:00")


def test_matches_never_leak_other_players_rows(client, make_player):
    pa, ha = make_player("alpha")
    pb, hb = make_player("bravo")
    db = client.SessionLocal()
    _result(db, "ONLYA1", pa, 1)
    db.commit()
    db.close()
    assert len(client.get("/api/matches", headers=ha).json()) == 1
    assert client.get("/api/matches", headers=hb).json() == []


def test_matches_limit(client, make_player):
    pa, ha = make_player("alpha")
    db = client.SessionLocal()
    for i in range(5):
        _result(db, f"R{i}", pa, 1, finished_at=datetime(2026, 1, 1) + timedelta(days=i))
    db.commit()
    db.close()
    assert len(client.get("/api/matches?limit=3", headers=ha).json()) == 3


def test_public_profile_has_no_private_fields(client, make_player):
    pa, ha = make_player("alpha")
    pb, hb = make_player("bravo")
    db = client.SessionLocal()
    b = db.query(Player).filter(Player.id == pb).first()
    b.rating, b.wins, b.losses, b.gold, b.total_xp = 1320, 4, 2, 999, 777
    db.add(PlayerBadge(player_id=pb, key="first_win"))
    db.commit()
    db.close()
    body = client.get(f"/api/players/{pb}/public", headers=ha).json()
    assert body["name"] == "bravo" and body["rating"] == 1320 and body["tier"] == "gold"
    assert body["wins"] == 4 and body["losses"] == 2 and body["total_xp"] == 777
    assert body["badges"] == ["first_win"]
    for private in ("gold", "hp", "token", "token_hash", "username", "email"):
        assert private not in body


def test_public_profile_404_and_requires_auth(client, make_player):
    _, ha = make_player("alpha")
    assert client.get("/api/players/9999/public", headers=ha).status_code == 404
    assert client.get("/api/players/1/public").status_code == 401
