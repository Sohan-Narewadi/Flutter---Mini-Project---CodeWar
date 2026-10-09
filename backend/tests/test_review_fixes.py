"""Regression tests for the whole-branch review findings."""
import random
from datetime import date, timedelta

import pytest

from app.judge import execute_case
from app.models import Player, Question
from app.qengine.templates import TEMPLATES, generate_from_template
from app.qengine.types import GeneratedQuestion
from app.qengine.verify import build_judge_cases, finalize
from app.rooms.engine import Room, RoomError
from app.schemas import VISIBLE_TEST_CASES

T0 = 1000.0


# ---- #1 hidden test cases ------------------------------------------------

def _next(client, **body):
    body.setdefault("difficulty", "easy")
    body.setdefault("topic", "math")
    return client.post("/api/practice/next", json=body).json()


def test_clients_only_see_the_first_few_test_cases(auth_client):
    pr = _next(auth_client)
    assert len(pr["question"]["test_cases"]) == VISIBLE_TEST_CASES
    db = auth_client.SessionLocal()
    stored = db.query(Question).filter(Question.id == pr["question"]["id"]).first()
    assert len(stored.judge_cases) > VISIBLE_TEST_CASES  # the rest are hidden judge cases
    db.close()


def test_hidden_case_results_do_not_leak_inputs_or_expected(auth_client):
    pr = _next(auth_client)
    r = auth_client.post(f"/api/practice/{pr['practice_id']}/run",
                         json={"code": "def nothing():\n    return 1\n", "language": "python"}).json()
    shown, hidden = r["results"][:VISIBLE_TEST_CASES], r["results"][VISIBLE_TEST_CASES:]
    assert hidden, "expected hidden cases"
    assert all(h["input"] == "(hidden)" and h["expected"] == "(hidden)" and h["actual"] == "(hidden)" for h in hidden)
    assert all(s["input"] != "(hidden)" for s in shown)
    assert r["total_tests"] == len(r["results"]) > VISIBLE_TEST_CASES


def test_hardcoding_visible_cases_does_not_pass(auth_client):
    pr = _next(auth_client)
    q = pr["question"]
    # Build a lookup from only the visible examples shown to the player.
    table = {c["input"]: c["expected_output"] for c in q["test_cases"]}
    code = f"def digit_sum(*a, **k):\n    return 0\nTABLE = {table!r}\n"
    r = auth_client.post(f"/api/practice/{pr['practice_id']}/submit", json={"code": code, "language": "python"}).json()
    assert r["solved"] is False


# ---- #4 players who never connected -----------------------------------------

def test_start_ignores_members_who_never_connected():
    r = Room("ABC123", "race", "easy", "python", 1, "host", T0)
    r.join(2, "ghost", T0)
    r.disconnect(2, T0)  # joined over REST, socket never opened
    with pytest.raises(RoomError) as e:
        r.start(1, T0)
    assert e.value.code == "need_players"


def test_start_drops_disconnected_lobby_members_so_they_cannot_be_forfeited_in():
    r = Room("ABC123", "race", "easy", "python", 1, "host", T0)
    r.join(2, "real", T0)
    r.join(3, "ghost", T0)
    r.disconnect(3, T0)
    r.start(1, T0)
    assert set(r.members) == {1, 2}
    r.tick(T0 + 3)
    r.tick(T0 + 100)
    assert r.status == "running" and not any(m.forfeited for m in r.members.values())


# ---- #9 a 0% submission is not a win -----------------------------------------

def test_zero_percent_submission_does_not_outrank_a_non_submitter():
    r = Room("ABC123", "duel", "easy", "python", 1, "a", T0)
    r.join(2, "b", T0)
    r.start(1, T0)
    r.tick(T0 + 3)
    r.submit(1, 0, 5, T0 + 10)
    r.tick(T0 + 3 + r.time_limit_s)
    assert {s["rank"] for s in r.standings()} == {1}  # both 0%: a draw


# ---- #7 / #12 judge robustness ----------------------------------------------------

def test_nondeterministic_llm_reference_is_rejected():
    ref = "import random\ndef f(x):\n    return random.random()\n"
    assert build_judge_cases("f", ref, [[1], [2], [3]], deterministic_check=True) is None
    # a deterministic reference with the same inputs is fine
    ok = "def f(x):\n    return x * 2\n"
    assert build_judge_cases("f", ok, [[1], [2], [3]], deterministic_check=True) is not None


def test_set_ordering_is_stable_across_runs():
    code = "def f(x):\n    return list({'a', 'b', 'c', 'd', 'e', 'f'})\n"
    outs = {tuple(execute_case("python", code, "f", [1])["value"]) for _ in range(6)}
    assert len(outs) == 1


def test_missing_runtime_is_a_failed_case_not_a_crash(monkeypatch):
    import subprocess

    def boom(*a, **k):
        raise FileNotFoundError("node")
    monkeypatch.setattr(subprocess, "run", boom)
    r = execute_case("typescript", "function f(){return 1}", "f", [])
    assert r["ok"] is False and "not available" in r["error"]


def test_llm_questions_get_the_determinism_check():
    gq = GeneratedQuestion(
        title="Flaky", difficulty="easy", topic="math", prompt="p", params=["x"], entry_python="f", entry_ts="f",
        reference_solution="import random\ndef f(x):\n    return random.randint(0, 10**9)\n",
        inputs=[[1], [2], [3], [4]], source="llm",
    )
    assert finalize(gq) is None


# ---- #10 lapsed streak is not shown -----------------------------------------------------

def test_player_endpoint_reports_a_lapsed_streak_as_zero(auth_client):
    db = auth_client.SessionLocal()
    p = db.query(Player).filter(Player.id == auth_client.player_id).first()
    p.streak, p.last_solve_date = 5, (date.today() - timedelta(days=3)).isoformat()
    db.commit()
    db.close()
    assert auth_client.get("/api/player").json()["streak"] == 0
    db = auth_client.SessionLocal()
    p = db.query(Player).filter(Player.id == auth_client.player_id).first()
    p.last_solve_date = (date.today() - timedelta(days=1)).isoformat()
    db.commit()
    db.close()
    assert auth_client.get("/api/player").json()["streak"] == 5


# ---- #2 a failed start must un-stick the lobby -----------------------------------

def test_failed_start_clears_preparing_for_everyone(client, make_player, monkeypatch):
    from app.rooms import manager as mgr
    monkeypatch.setattr(mgr, "COUNTDOWN_S", 0.2)
    monkeypatch.setattr(mgr, "TICK_S", 0.05)

    def broken(self, rt):
        raise RuntimeError("generator down")
    monkeypatch.setattr(mgr.RoomManager, "_make_question", broken)

    _, ha = make_player("alpha")
    _, hb = make_player("bravo")
    code = client.post("/api/rooms", json={}, headers=ha).json()["code"]
    ta, tb = ha["Authorization"].split(" ")[1], hb["Authorization"].split(" ")[1]
    with client.websocket_connect(f"/ws/rooms/{code}?token={ta}") as wa, \
         client.websocket_connect(f"/ws/rooms/{code}?token={tb}"):
        wa.send_json({"type": "start"})
        seen_error = False
        cleared_after_prepare = False
        was_preparing = False
        for _ in range(30):
            m = wa.receive_json()
            if m["type"] == "error":
                assert m["code"] == "no_question"
                seen_error = True
            if m["type"] == "snapshot":
                if m["room"]["preparing"]:
                    was_preparing = True
                elif was_preparing:
                    cleared_after_prepare = True
            if seen_error and cleared_after_prepare:
                break
        else:
            raise AssertionError("never saw both the error and a cleared preparing flag")
