from datetime import datetime, timedelta, timezone

from app.models import Player
from app.progress import award_xp, current_week

CORRECT_FIND_MAX = "def find_maximum(nums):\n    return max(nums) if nums else None\n"


def _set(client, player_id, **fields):
    db = client.SessionLocal()
    p = db.query(Player).filter(Player.id == player_id).first()
    for k, v in fields.items():
        setattr(p, k, v)
    db.commit()
    db.close()


def test_award_xp_levels_up_and_tracks_totals():
    p = Player(username="x", display_name="X", level=1, xp=900, xp_to_next=1000, hp=100, hp_max=100,
               gold=0, streak=0, rating=1000, wins=0, losses=0, total_xp=900, weekly_xp=0, weekly_week="")
    award_xp(p, xp=250, gold=5)
    assert p.level == 2 and p.xp == 150 and p.xp_to_next == 1200
    assert p.total_xp == 1150 and p.weekly_xp == 250 and p.gold == 5
    assert p.weekly_week == current_week()


def test_award_xp_rolls_over_stale_week():
    p = Player(username="x", display_name="X", level=1, xp=0, xp_to_next=1000, hp=100, hp_max=100,
               gold=0, streak=0, rating=1000, wins=0, losses=0, total_xp=500, weekly_xp=400, weekly_week="1999-W01")
    award_xp(p, xp=10, gold=0)
    assert p.weekly_xp == 10


def test_global_leaderboard_orders_by_total_xp_and_reports_me(client, make_player):
    ida, ha = make_player("alpha")
    idb, hb = make_player("bravo")
    idc, hc = make_player("charlie")
    _set(client, ida, total_xp=500)
    _set(client, idb, total_xp=900)
    _set(client, idc, total_xp=100)
    body = client.get("/api/leaderboard", params={"scope": "global"}, headers=ha).json()
    assert [e["name"] for e in body["entries"]] == ["bravo", "alpha", "charlie"]
    assert [e["rank"] for e in body["entries"]] == [1, 2, 3]
    assert body["me"]["name"] == "alpha" and body["me"]["rank"] == 2
    assert [e["is_me"] for e in body["entries"]] == [False, True, False]


def test_me_is_returned_even_when_outside_limit(client, make_player):
    ids = []
    for i in range(5):
        pid, h = make_player(f"p{i}")
        ids.append((pid, h))
        _set(client, pid, total_xp=1000 - i * 100)
    _, last_headers = ids[-1]
    body = client.get("/api/leaderboard", params={"scope": "global", "limit": 2}, headers=last_headers).json()
    assert len(body["entries"]) == 2
    assert body["me"]["rank"] == 5


def test_rating_metric(client, make_player):
    ida, ha = make_player("alpha")
    idb, hb = make_player("bravo")
    _set(client, ida, rating=1200, total_xp=0)
    _set(client, idb, rating=900, total_xp=5000)
    by_xp = client.get("/api/leaderboard", params={"metric": "xp"}, headers=ha).json()
    by_rating = client.get("/api/leaderboard", params={"metric": "rating"}, headers=ha).json()
    assert by_xp["entries"][0]["name"] == "bravo"
    assert by_rating["entries"][0]["name"] == "alpha"
    assert by_rating["entries"][0]["value"] == 1200


def test_weekly_scope_ignores_stale_weeks(client, make_player):
    ida, ha = make_player("alpha")
    idb, hb = make_player("bravo")
    _set(client, ida, weekly_xp=50, weekly_week=current_week())
    _set(client, idb, weekly_xp=9999, weekly_week="1999-W01")
    body = client.get("/api/leaderboard", params={"scope": "weekly"}, headers=ha).json()
    assert body["entries"][0]["name"] == "alpha" and body["entries"][0]["value"] == 50
    stale = [e for e in body["entries"] if e["name"] == "bravo"]
    assert stale == [] or stale[0]["value"] == 0


def test_friends_scope_only_lists_friends_and_self(client, make_player):
    ida, ha = make_player("alpha")
    idb, hb = make_player("bravo")
    idc, hc = make_player("charlie")
    assert client.post("/api/friends", json={"name": "Bravo"}, headers=ha).status_code == 200
    body = client.get("/api/leaderboard", params={"scope": "friends"}, headers=ha).json()
    assert {e["name"] for e in body["entries"]} == {"alpha", "bravo"}
    # friendship is mutual
    body_b = client.get("/api/leaderboard", params={"scope": "friends"}, headers=hb).json()
    assert {e["name"] for e in body_b["entries"]} == {"alpha", "bravo"}


def test_add_friend_validation(client, make_player):
    ida, ha = make_player("alpha")
    assert client.post("/api/friends", json={"name": "nobody"}, headers=ha).status_code == 404
    assert client.post("/api/friends", json={"name": "alpha"}, headers=ha).status_code == 400
    make_player("bravo")
    assert client.post("/api/friends", json={"name": "bravo"}, headers=ha).status_code == 200
    assert client.post("/api/friends", json={"name": "bravo"}, headers=ha).status_code == 200  # idempotent


def test_invalid_scope_and_auth(client, auth_client):
    assert auth_client.get("/api/leaderboard", params={"scope": "nope"}).status_code == 422
    assert auth_client.get("/api/leaderboard", params={"metric": "nope"}).status_code == 422
    client.headers.pop("Authorization", None)
    assert client.get("/api/leaderboard").status_code == 401


def test_battle_win_adds_total_xp(auth_client):
    bid = auth_client.post("/api/battles/start", json={"level_id": 3}).json()["battle_id"]
    for _ in range(4):
        r = auth_client.post(f"/api/battles/{bid}/submit", json={"code": CORRECT_FIND_MAX}).json()
        if r["outcome"] == "won":
            break
    board = auth_client.get("/api/leaderboard").json()
    assert board["me"]["value"] == r["xp_earned"] > 0
