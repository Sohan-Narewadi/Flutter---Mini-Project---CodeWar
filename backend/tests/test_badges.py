from app.badges import BADGES, award_badges
from app.migrate import ensure_columns
from app.models import PlayerBadge, PracticeAttempt, PracticeStat, Player, Question, RoomResult


def _earned(client, headers=None):
    body = client.get("/api/badges", headers=headers or {}).json()
    return {b["key"] for b in body if b["earned_at"]}


def test_catalogue_lists_every_badge_unearned_for_new_player(auth_client):
    body = auth_client.get("/api/badges").json()
    assert {b["key"] for b in body} == set(BADGES)
    assert all(b["earned_at"] is None for b in body)
    assert all(b["name"] and b["description"] and b["icon"] for b in body)


def test_wins_award_first_win_then_win_5(auth_client):
    db = auth_client.SessionLocal()
    p = db.query(Player).filter(Player.id == auth_client.player_id).first()
    p.wins = 1
    db.commit()
    assert "first_win" in _earned(auth_client)
    assert "win_5" not in _earned(auth_client)
    p.wins = 5
    db.commit()
    db.close()
    assert {"first_win", "win_5"} <= _earned(auth_client)


def test_award_is_idempotent_and_returns_only_new(auth_client):
    db = auth_client.SessionLocal()
    p = db.query(Player).filter(Player.id == auth_client.player_id).first()
    p.wins = 1
    db.commit()
    assert award_badges(db, p) == ["first_win"]
    db.commit()
    assert award_badges(db, p) == []
    assert db.query(PlayerBadge).filter(PlayerBadge.player_id == p.id).count() == 1
    db.close()


def test_best_streak_badges_use_the_best_streak_not_the_current(auth_client):
    db = auth_client.SessionLocal()
    p = db.query(Player).filter(Player.id == auth_client.player_id).first()
    p.streak, p.best_streak = 0, 7
    db.commit()
    db.close()
    got = _earned(auth_client)
    assert {"streak_3", "streak_7"} <= got
    assert "streak_30" not in got


def test_practice_badges(auth_client):
    db = auth_client.SessionLocal()
    pid = auth_client.player_id
    db.add(PracticeStat(player_id=pid, topic="math", points=100, solved=10))
    db.add(PracticeAttempt(player_id=pid, question_id="q1", topic="math", difficulty="hard", daily=True,
                           status="solved", best_percent=100, solved_on="2026-01-01"))
    db.commit()
    db.close()
    got = _earned(auth_client)
    assert {"first_solve", "solve_10", "topic_master", "daily_done", "hard_solver"} <= got
    assert "solve_100" not in got


def test_rooms_and_rating_badges(auth_client):
    db = auth_client.SessionLocal()
    pid = auth_client.player_id
    for i in range(10):
        db.add(RoomResult(room_code=f"R{i}", mode="race", player_id=pid, rank=2))
    p = db.query(Player).filter(Player.id == pid).first()
    p.rating = 1150
    db.commit()
    db.close()
    assert {"rival", "climber"} <= _earned(auth_client)


def test_level_badges(auth_client):
    db = auth_client.SessionLocal()
    p = db.query(Player).filter(Player.id == auth_client.player_id).first()
    p.level = 5
    db.commit()
    db.close()
    got = _earned(auth_client)
    assert "level_5" in got and "level_10" not in got


def test_practice_submit_reports_new_badges(auth_client):
    pr = auth_client.post("/api/practice/next", json={"difficulty": "easy", "topic": "math"}).json()
    db = auth_client.SessionLocal()
    code = db.query(Question).filter(Question.id == pr["question"]["id"]).first().reference_solution
    db.close()
    body = {"code": code, "language": "python"}
    r = auth_client.post(f"/api/practice/{pr['practice_id']}/submit", json=body).json()
    assert [b["key"] for b in r["new_badges"]] == ["first_solve"]
    r2 = auth_client.post(f"/api/practice/{pr['practice_id']}/submit", json=body).json()
    assert r2["new_badges"] == []


def test_badges_are_private_per_player(client, make_player):
    _, ha = make_player("alpha")
    _, hb = make_player("bravo")
    db = client.SessionLocal()
    a = db.query(Player).filter(Player.username == "alpha").first()
    a.wins = 1
    db.commit()
    db.close()
    assert "first_win" in _earned(client, ha)
    assert "first_win" not in _earned(client, hb)


def test_ensure_columns_upgrades_an_old_database(tmp_path):
    from sqlalchemy import create_engine, inspect, text

    engine = create_engine(f"sqlite:///{tmp_path / 'old.db'}")
    with engine.begin() as c:
        c.execute(text("CREATE TABLE players (id INTEGER PRIMARY KEY, username VARCHAR NOT NULL, display_name VARCHAR NOT NULL)"))
        c.execute(text("INSERT INTO players (username, display_name) VALUES ('a','A')"))
    added = ensure_columns(engine)
    assert "players.best_streak" in added and "players.rating" in added
    assert "best_streak" in {c["name"] for c in inspect(engine).get_columns("players")}
    with engine.begin() as c:
        assert tuple(c.execute(text("SELECT best_streak, rating FROM players")).one()) == (0, 1000)
    assert ensure_columns(engine) == []
