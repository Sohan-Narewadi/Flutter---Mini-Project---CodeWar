from datetime import date, timedelta

from app.models import Player, Question


def _next(c, headers=None, **body):
    body.setdefault("difficulty", "easy")
    body.setdefault("topic", "math")
    return c.post("/api/practice/next", json=body, headers=headers or {})


def _reference(client, question_id):
    db = client.SessionLocal()
    code = db.query(Question).filter(Question.id == question_id).first().reference_solution
    db.close()
    return code


def test_next_returns_question_and_attempt(auth_client):
    r = _next(auth_client)
    assert r.status_code == 200
    body = r.json()
    assert body["practice_id"] > 0
    q = body["question"]
    assert q["topic"] == "math" and q["starter_code"]["python"] and q["test_cases"]
    assert "judge_cases" not in q and "reference_solution" not in q


def test_next_validation_and_auth(client, auth_client):
    assert _next(auth_client, difficulty="nope").status_code == 422
    assert _next(auth_client, topic="nope").status_code == 422
    client.headers.pop("Authorization", None)
    assert _next(client).status_code == 401


def test_run_does_not_award_anything(auth_client):
    pr = _next(auth_client).json()
    code = _reference(auth_client, pr["question"]["id"])
    r = auth_client.post(f"/api/practice/{pr['practice_id']}/run", json={"code": code, "language": "python"})
    assert r.status_code == 200 and r.json()["correctness_percent"] == 100
    assert auth_client.get("/api/player").json()["xp"] == 0


def test_correct_submit_awards_once_and_updates_mastery_and_streak(auth_client):
    pr = _next(auth_client).json()
    code = _reference(auth_client, pr["question"]["id"])
    first = auth_client.post(f"/api/practice/{pr['practice_id']}/submit", json={"code": code, "language": "python"}).json()
    assert first["solved"] is True and first["correctness_percent"] == 100
    assert first["xp_earned"] == 20 and first["gold_earned"] > 0
    again = auth_client.post(f"/api/practice/{pr['practice_id']}/submit", json={"code": code, "language": "python"}).json()
    assert again["solved"] is True and again["xp_earned"] == 0
    stats = auth_client.get("/api/practice/stats").json()
    math = next(t for t in stats["topics"] if t["id"] == "math")
    assert math["solved"] == 1 and math["mastery_percent"] > 0
    assert stats["streak"] == 1 and stats["solved_today"] == 1
    assert auth_client.get("/api/player").json()["xp"] == 20


def test_wrong_submit_does_not_solve_or_cost_hp(auth_client):
    pr = _next(auth_client).json()
    hp_before = auth_client.get("/api/player").json()["hp"]
    r = auth_client.post(f"/api/practice/{pr['practice_id']}/submit",
                         json={"code": "def nothing():\n    return None\n", "language": "python"}).json()
    assert r["solved"] is False and r["xp_earned"] == 0
    assert auth_client.get("/api/player").json()["hp"] == hp_before


def test_practice_attempt_is_private(client, make_player):
    _, ha = make_player("alpha")
    _, hb = make_player("bravo")
    pid = _next(client, ha).json()["practice_id"]
    for path in ("run", "submit"):
        assert client.post(f"/api/practice/{pid}/{path}", json={"code": "x"}, headers=hb).status_code == 403
    assert client.post(f"/api/practice/{pid}/hint", headers=hb).status_code == 403
    assert client.post("/api/practice/9999/submit", json={"code": "x"}, headers=ha).status_code == 404


def test_hints_escalate_and_are_counted(auth_client):
    pid = _next(auth_client).json()["practice_id"]
    hints = [auth_client.post(f"/api/practice/{pid}/hint").json() for _ in range(4)]
    assert [h["level"] for h in hints] == [1, 2, 3, 3]
    assert all(h["hint"] for h in hints)
    assert hints[0]["hint"] != hints[1]["hint"]


def test_streak_continues_after_yesterday_and_resets_after_gap(auth_client):
    pid = auth_client.player_id

    def solve():
        pr = _next(auth_client).json()
        code = _reference(auth_client, pr["question"]["id"])
        return auth_client.post(f"/api/practice/{pr['practice_id']}/submit", json={"code": code, "language": "python"}).json()

    db = auth_client.SessionLocal()
    p = db.query(Player).filter(Player.id == pid).first()
    p.streak, p.last_solve_date = 4, (date.today() - timedelta(days=1)).isoformat()
    db.commit()
    db.close()
    solve()
    assert auth_client.get("/api/practice/stats").json()["streak"] == 5

    db = auth_client.SessionLocal()
    p = db.query(Player).filter(Player.id == pid).first()
    p.streak, p.last_solve_date = 9, (date.today() - timedelta(days=3)).isoformat()
    db.commit()
    db.close()
    solve()
    assert auth_client.get("/api/practice/stats").json()["streak"] == 1


def test_daily_challenge_is_same_for_everyone_and_double_xp_once(client, make_player):
    _, ha = make_player("alpha")
    _, hb = make_player("bravo")
    qa = _next(client, ha, daily=True, difficulty="medium", topic=None).json()
    qb = _next(client, hb, daily=True, difficulty="medium", topic=None).json()
    assert qa["question"]["id"] == qb["question"]["id"]
    code = _reference(client, qa["question"]["id"])
    r1 = client.post(f"/api/practice/{qa['practice_id']}/submit", json={"code": code, "language": "python"}, headers=ha).json()
    assert r1["xp_earned"] == 80  # medium 40, doubled for the daily
    qa2 = _next(client, ha, daily=True, difficulty="medium", topic=None).json()
    r2 = client.post(f"/api/practice/{qa2['practice_id']}/submit", json={"code": code, "language": "python"}, headers=ha).json()
    assert r2["xp_earned"] == 0  # daily bonus only once per day


def test_stats_lists_every_topic(auth_client):
    stats = auth_client.get("/api/practice/stats").json()
    assert {t["id"] for t in stats["topics"]} == {"arrays", "strings", "math", "hashmap", "two-pointers", "dp"}
    assert stats["streak"] == 0 and stats["solved_today"] == 0


def test_stats_total_solved_and_daily_flags(auth_client):
    stats = auth_client.get("/api/practice/stats").json()
    assert stats["total_solved"] == 0 and stats["daily_done"] is False
    assert 0 < stats["daily_resets_in"] <= 24 * 3600

    pr = _next(auth_client, daily=True, difficulty="medium", topic=None).json()
    code = _reference(auth_client, pr["question"]["id"])
    r = auth_client.post(f"/api/practice/{pr['practice_id']}/submit", json={"code": code, "language": "python"}).json()
    assert r["solved"] is True
    stats = auth_client.get("/api/practice/stats").json()
    assert stats["total_solved"] == 1 and stats["daily_done"] is True


def test_plain_solve_does_not_mark_daily_done(auth_client):
    pr = _next(auth_client).json()
    code = _reference(auth_client, pr["question"]["id"])
    auth_client.post(f"/api/practice/{pr['practice_id']}/submit", json={"code": code, "language": "python"})
    stats = auth_client.get("/api/practice/stats").json()
    assert stats["total_solved"] == 1 and stats["daily_done"] is False
