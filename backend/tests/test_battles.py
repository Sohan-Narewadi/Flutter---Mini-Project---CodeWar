def test_start_battle_unknown_level(auth_client):
    res = auth_client.post("/api/battles/start", json={"level_id": 999})
    assert res.status_code == 404


def test_start_battle_known_level(auth_client):
    res = auth_client.post("/api/battles/start", json={"level_id": 3})
    assert res.status_code == 200
    body = res.json()
    assert body["battle_id"] > 0
    assert body["enemy_hp_remaining"] == 1000  # e_array_beast.hp_max
    assert body["time_limit_s"] == 240  # level 3 difficulty="easy"
    assert body["question"]["id"] == "q_find_max"  # level 3 -> q_find_max


CORRECT_FIND_MAX = (
    "def find_maximum(nums):\n"
    "    if not nums:\n"
    "        return None\n"
    "    m = nums[0]\n"
    "    for n in nums:\n"
    "        if n > m:\n"
    "            m = n\n"
    "    return m"
)


def test_run_battle_all_pass(auth_client):
    start = auth_client.post("/api/battles/start", json={"level_id": 3})
    battle_id = start.json()["battle_id"]

    res = auth_client.post(f"/api/battles/{battle_id}/run", json={"code": CORRECT_FIND_MAX, "language": "python"})
    assert res.status_code == 200
    body = res.json()
    assert body["passed_tests"] == 3
    assert body["total_tests"] == 3
    assert body["correctness_percent"] == 100


def test_run_battle_does_not_mutate_enemy_hp(auth_client):
    start = auth_client.post("/api/battles/start", json={"level_id": 3})
    battle_id = start.json()["battle_id"]

    auth_client.post(f"/api/battles/{battle_id}/run", json={"code": CORRECT_FIND_MAX, "language": "python"})

    submit = auth_client.post(f"/api/battles/{battle_id}/submit", json={"code": CORRECT_FIND_MAX, "language": "python"})
    # If /run had already damaged the enemy, this first submit's damage would
    # land on a partially-depleted hp_remaining instead of the full hp_max.
    assert submit.json()["enemy_hp_remaining"] == 1000 - submit.json()["damage_dealt"]


def test_run_battle_unknown_battle(auth_client):
    res = auth_client.post("/api/battles/9999/run", json={"code": "x", "language": "python"})
    assert res.status_code == 404


def test_run_battle_unsupported_language(auth_client):
    start = auth_client.post("/api/battles/start", json={"level_id": 3})
    battle_id = start.json()["battle_id"]
    res = auth_client.post(f"/api/battles/{battle_id}/run", json={"code": "int x;", "language": "cpp"})
    assert res.status_code == 400


BUGGY_FIND_MAX = (
    "def find_maximum(nums):\n"
    "    if not nums:\n"
    "        return 0\n"
    "    m = nums[0]\n"
    "    for n in nums:\n"
    "        if n > m:\n"
    "            m = n\n"
    "    return m"
)


def test_submit_partial_credit_does_not_finalize_and_damages_player(auth_client):
    start = auth_client.post("/api/battles/start", json={"level_id": 3})
    battle_id = start.json()["battle_id"]

    res = auth_client.post(f"/api/battles/{battle_id}/submit", json={"code": BUGGY_FIND_MAX, "language": "python"})
    assert res.status_code == 200
    body = res.json()
    assert body["passed_tests"] == 2
    assert body["total_tests"] == 3
    assert body["outcome"] == "in_progress"
    assert body["hp_lost"] > 0
    assert body["damage_dealt"] > 0


def test_submit_full_credit_repeated_wins_and_rejects_resubmit(auth_client):
    start = auth_client.post("/api/battles/start", json={"level_id": 3})
    battle_id = start.json()["battle_id"]

    # e_array_beast hp_max=1000; damage per 100%-correct hit = ceil(1000/3) = 334
    r1 = auth_client.post(f"/api/battles/{battle_id}/submit", json={"code": CORRECT_FIND_MAX, "language": "python"}).json()
    assert r1["outcome"] == "in_progress"
    assert r1["damage_dealt"] == 334
    assert r1["enemy_hp_remaining"] == 666

    r2 = auth_client.post(f"/api/battles/{battle_id}/submit", json={"code": CORRECT_FIND_MAX, "language": "python"}).json()
    assert r2["enemy_hp_remaining"] == 332

    r3 = auth_client.post(f"/api/battles/{battle_id}/submit", json={"code": CORRECT_FIND_MAX, "language": "python"}).json()
    assert r3["outcome"] == "won"
    assert r3["enemy_defeated"] is True
    assert r3["enemy_hp_remaining"] == 0
    assert r3["xp_earned"] == 100  # level 3 xp_reward
    assert r3["gold_earned"] == 40  # level 3 gold_reward

    resubmit = auth_client.post(f"/api/battles/{battle_id}/submit", json={"code": CORRECT_FIND_MAX, "language": "python"})
    assert resubmit.status_code == 400


def test_submit_after_deadline_expires(auth_client):
    from datetime import datetime, timedelta, timezone
    from app.models.battle import Battle

    start = auth_client.post("/api/battles/start", json={"level_id": 3})
    battle_id = start.json()["battle_id"]

    db = auth_client.SessionLocal()
    battle = db.query(Battle).filter(Battle.id == battle_id).first()
    battle.started_at = datetime.now(timezone.utc) - timedelta(seconds=400)
    db.commit()
    db.close()

    res = auth_client.post(f"/api/battles/{battle_id}/submit", json={"code": CORRECT_FIND_MAX, "language": "python"})
    assert res.status_code == 200
    assert res.json()["outcome"] == "expired"


def test_submit_unknown_battle(auth_client):
    res = auth_client.post("/api/battles/9999/submit", json={"code": "x", "language": "python"})
    assert res.status_code == 404


def test_campaign_win_does_not_count_as_an_online_win_but_earns_badges(auth_client):
    battle_id = auth_client.post("/api/battles/start", json={"level_id": 3}).json()["battle_id"]
    for _ in range(3):
        auth_client.post(f"/api/battles/{battle_id}/submit", json={"code": CORRECT_FIND_MAX, "language": "python"})
    me = auth_client.get("/api/player").json()
    assert me["wins"] == 0 and me["losses"] == 0  # the online record is online-only
    earned = {b["key"] for b in auth_client.get("/api/badges").json() if b["earned"]}
    assert "first_solve" in earned  # a cleared campaign level counts as a first solve
