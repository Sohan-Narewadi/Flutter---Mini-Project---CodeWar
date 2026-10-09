from datetime import datetime, timedelta, timezone

from app.judge import values_equal
from app.models import Player

CORRECT_FIND_MAX = (
    "def find_maximum(nums):\n"
    "    return max(nums) if nums else None\n"
)


def _win(c, level_id, headers=None):
    h = headers or {}
    bid = c.post("/api/battles/start", json={"level_id": level_id}, headers=h).json()["battle_id"]
    for _ in range(4):
        r = c.post(f"/api/battles/{bid}/submit", json={"code": CORRECT_FIND_MAX}, headers=h).json()
        if r["outcome"] == "won":
            return r
    raise AssertionError("did not win")


def test_levels_are_per_player(client, make_player):
    _, ha = make_player("alpha")
    _, hb = make_player("bravo")
    lv = client.get("/api/levels", params={"world_id": "w2"}, headers=ha).json()
    assert [l["status"] for l in lv][:2] == ["current", "locked"]
    _win(client, 1, ha)
    lva = client.get("/api/levels", params={"world_id": "w2"}, headers=ha).json()
    lvb = client.get("/api/levels", params={"world_id": "w2"}, headers=hb).json()
    assert [l["status"] for l in lva][:2] == ["completed", "current"]
    assert lva[0]["stars"] == 3
    assert [l["status"] for l in lvb][:2] == ["current", "locked"]


def test_world_cleared_percent_per_player(client, make_player):
    _, ha = make_player("alpha")
    _, hb = make_player("bravo")
    _win(client, 1, ha)
    assert client.get("/api/worlds", headers=ha).json()[0]["cleared_percent"] == 12  # 1/8
    assert client.get("/api/worlds", headers=hb).json()[0]["cleared_percent"] == 0


def test_enemy_defeated_flag_per_player(client, make_player):
    _, ha = make_player("alpha")
    _, hb = make_player("bravo")
    r = _win(client, 1, ha)
    enemy_id = client.get("/api/levels", params={"world_id": "w2"}, headers=ha).json()[0]["enemy_id"]
    ea = {e["id"]: e for e in client.get("/api/enemies", headers=ha).json()}
    eb = {e["id"]: e for e in client.get("/api/enemies", headers=hb).json()}
    assert ea[enemy_id]["defeated"] is True
    assert eb[enemy_id]["defeated"] is False


def test_cannot_use_other_players_battle(client, make_player):
    _, ha = make_player("alpha")
    _, hb = make_player("bravo")
    bid = client.post("/api/battles/start", json={"level_id": 1}, headers=ha).json()["battle_id"]
    for path in ("run", "submit"):
        r = client.post(f"/api/battles/{bid}/{path}", json={"code": "x"}, headers=hb)
        assert r.status_code == 403


def test_battle_endpoints_require_auth(client):
    assert client.post("/api/battles/start", json={"level_id": 1}).status_code == 401
    assert client.get("/api/levels", params={"world_id": "w2"}).status_code == 401


def test_cannot_start_locked_level(auth_client):
    r = auth_client.post("/api/battles/start", json={"level_id": 5})
    assert r.status_code == 403


def test_run_blocked_after_battle_ends(auth_client):
    r = _win(auth_client, 1)
    bid = auth_client.post("/api/battles/start", json={"level_id": 1}).json()["battle_id"]
    # finish it
    for _ in range(4):
        if auth_client.post(f"/api/battles/{bid}/submit", json={"code": CORRECT_FIND_MAX}).json()["outcome"] == "won":
            break
    res = auth_client.post(f"/api/battles/{bid}/run", json={"code": CORRECT_FIND_MAX})
    assert res.status_code == 400


def test_hp_regenerates_over_time(auth_client):
    db = auth_client.SessionLocal()
    p = db.query(Player).filter(Player.id == auth_client.player_id).first()
    p.hp = 50
    p.hp_updated_at = (datetime.now(timezone.utc) - timedelta(seconds=95)).replace(tzinfo=None)
    db.commit()
    db.close()
    assert auth_client.get("/api/player").json()["hp"] == 53


def test_hp_regen_caps_at_max(auth_client):
    db = auth_client.SessionLocal()
    p = db.query(Player).filter(Player.id == auth_client.player_id).first()
    p.hp = p.hp_max - 1
    p.hp_updated_at = (datetime.now(timezone.utc) - timedelta(hours=5)).replace(tzinfo=None)
    db.commit()
    db.close()
    body = auth_client.get("/api/player").json()
    assert body["hp"] == body["hp_max"]


def test_values_equal_is_type_strict():
    assert values_equal(1, 1.0) is True
    assert values_equal(True, 1) is False
    assert values_equal([1], [True]) is False
    assert values_equal([1, [2.0]], [1, [2]]) is True
    assert values_equal({"a": 1}, {"a": 1}) is True
    assert values_equal(None, None) is True
    assert values_equal("1", 1) is False
