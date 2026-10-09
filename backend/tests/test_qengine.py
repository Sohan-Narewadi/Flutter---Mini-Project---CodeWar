import json
import random

import pytest

from app.models import Question
from app.qengine import service
from app.qengine.llm import generate_with_llm
from app.qengine.templates import TEMPLATES, TOPICS, generate_from_template
from app.qengine.types import GeneratedQuestion
from app.qengine.verify import build_judge_cases, finalize

GOOD_REF = "def add(a, b):\n    return a + b\n"


# ---- verification -------------------------------------------------------

def test_build_judge_cases_computes_expected_from_reference():
    cases = build_judge_cases("add", GOOD_REF, [[1, 2], [3, 4], [0, 0]])
    assert cases == [
        {"args": [1, 2], "expected": 3},
        {"args": [3, 4], "expected": 7},
        {"args": [0, 0], "expected": 0},
    ]


def test_build_judge_cases_rejects_crashing_reference():
    assert build_judge_cases("add", "def add(a, b):\n    return a + b + undefined\n", [[1, 2], [2, 3], [3, 4]]) is None


def test_build_judge_cases_rejects_constant_output():
    assert build_judge_cases("add", "def add(a, b):\n    return 1\n", [[1, 2], [2, 3], [3, 4]]) is None


def test_build_judge_cases_rejects_too_few_inputs():
    assert build_judge_cases("add", GOOD_REF, [[1, 2], [3, 4]]) is None


def test_build_judge_cases_rejects_wrong_entry_point():
    assert build_judge_cases("nope", GOOD_REF, [[1, 2], [3, 4], [5, 6]]) is None


# ---- templates ----------------------------------------------------------

def test_template_catalog_is_big_enough():
    assert len(TEMPLATES) >= 25
    for topic in TOPICS:
        for diff in ("easy", "medium", "hard"):
            assert any(t.topic == topic and t.difficulty == diff for t in TEMPLATES), (topic, diff)


@pytest.mark.parametrize("template", TEMPLATES, ids=lambda t: t.fn)
def test_every_template_generates_a_verifiable_question(template):
    gq = generate_from_template(random.Random(7), template=template)
    out = finalize(gq)
    assert out is not None, f"{template.fn} failed verification"
    assert len(out["judge_cases"]) >= 3
    assert out["entry_point"]["python"] == template.fn
    assert "typescript" in out["starter_code"] and "python" in out["starter_code"]
    assert out["difficulty"] == template.difficulty.title()


def test_templates_vary_between_seeds():
    t = next(t for t in TEMPLATES if t.fn == "count_multiples")
    a = finalize(generate_from_template(random.Random(1), template=t))
    b = finalize(generate_from_template(random.Random(2), template=t))
    assert a["content_hash"] != b["content_hash"]


def test_reference_solutions_are_correct_on_known_cases():
    known = {
        "second_largest": ([[3, 1, 4, 1, 5]], 4),
        "max_subarray": ([[-2, 1, -3, 4, -1, 2, 1, -5, 4]], 6),
        "is_palindrome": (["A man, a plan, a canal: Panama"], True),
        "longest_unique": (["abcabcbb"], 3),
        "count_primes": ([10], 4),
        "edit_distance": (["kitten", "sitting"], 3),
        "min_coins": ([[1, 2, 5], 11], 3),
        "count_triplets_zero": ([[-1, 0, 1, 2, -1, -4]], 2),
        "climb_stairs": ([5], 8),
        "max_area": ([[1, 8, 6, 2, 5, 4, 8, 3, 7]], 49),
    }
    from app.judge import execute_case
    for fn, (args, expected) in known.items():
        t = next(t for t in TEMPLATES if t.fn == fn)
        gq = generate_from_template(random.Random(0), template=t)
        r = execute_case("python", gq.reference_solution, fn, args)
        assert r["ok"] and r["value"] == expected, (fn, r)


# ---- LLM ----------------------------------------------------------------

LLM_JSON = json.dumps({
    "title": "Add Two Numbers",
    "topic": "math",
    "prompt": "Return a + b.",
    "function_name": "add_two",
    "params": ["a", "b"],
    "reference_solution": "def add_two(a, b):\n    return a + b\n",
    "inputs": [[1, 2], [5, 5], [0, 9], [-3, 3], [10, 20]],
})


def test_llm_valid_json_becomes_generated_question():
    gq = generate_with_llm("easy", "math", complete=lambda prompt: "```json\n" + LLM_JSON + "\n```")
    assert gq is not None and gq.source == "llm"
    assert gq.entry_python == "add_two" and gq.entry_ts == "addTwo"
    assert finalize(gq) is not None


@pytest.mark.parametrize("raw", ["not json at all", "{}", '{"title": 1}', ""])
def test_llm_malformed_output_returns_none(raw):
    assert generate_with_llm("easy", "math", complete=lambda prompt: raw) is None


def test_llm_exception_returns_none():
    def boom(prompt):
        raise RuntimeError("network down")
    assert generate_with_llm("easy", "math", complete=boom) is None


def test_llm_rejects_dangerous_reference():
    bad = json.loads(LLM_JSON)
    bad["reference_solution"] = "import os\ndef add_two(a, b):\n    os.system('echo hi')\n    return a + b\n"
    assert generate_with_llm("easy", "math", complete=lambda p: json.dumps(bad)) is None


def test_llm_without_key_returns_none(monkeypatch):
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    assert generate_with_llm("easy", "math") is None


# ---- service ------------------------------------------------------------

def _no_llm(difficulty, topic):
    return None


def _fake_llm(difficulty, topic):
    return GeneratedQuestion(
        title="Add Two Numbers", difficulty=difficulty, topic=topic or "math", prompt="Return a + b.",
        params=["a", "b"], entry_python="add_two", entry_ts="addTwo",
        reference_solution="def add_two(a, b):\n    return a + b\n",
        inputs=[[1, 2], [5, 5], [0, 9], [-3, 3]], source="llm",
    )


def test_service_falls_back_to_template(auth_client):
    db = auth_client.SessionLocal()
    q = service.get_question(db, auth_client.player_id, "easy", "arrays", llm=_no_llm, rng=random.Random(1))
    assert q.source == "template" and q.topic == "arrays" and q.difficulty == "Easy"
    assert db.query(Question).filter(Question.id == q.id).first() is not None
    db.close()


def test_service_prefers_llm_when_available(auth_client):
    db = auth_client.SessionLocal()
    q = service.get_question(db, auth_client.player_id, "easy", "math", llm=_fake_llm, rng=random.Random(1))
    assert q.source == "llm" and q.title == "Add Two Numbers"
    db.close()


def test_service_uses_cached_llm_question_when_llm_down_and_unseen(auth_client, make_player):
    db = auth_client.SessionLocal()
    first = service.get_question(db, auth_client.player_id, "easy", "math", llm=_fake_llm, rng=random.Random(1))
    other_id, _ = make_player("Other")
    again = service.get_question(db, other_id, "easy", "math", llm=_no_llm, rng=random.Random(1))
    assert again.id == first.id  # unseen cached question beats a template
    third = service.get_question(db, other_id, "easy", "math", llm=_no_llm, rng=random.Random(1))
    assert third.id != first.id  # already seen -> fresh template
    db.close()


def test_service_invalid_difficulty_raises(auth_client):
    db = auth_client.SessionLocal()
    with pytest.raises(ValueError):
        service.get_question(db, auth_client.player_id, "impossible", None, llm=_no_llm)
    db.close()


# ---- endpoints ----------------------------------------------------------

def test_generate_endpoint_returns_question_without_judge_data(auth_client, monkeypatch):
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    r = auth_client.post("/api/questions/generate", json={"difficulty": "medium", "topic": "strings"})
    assert r.status_code == 200
    body = r.json()
    assert body["topic"] == "strings" and body["source"] == "template"
    assert body["starter_code"]["python"] and body["test_cases"]
    assert "judge_cases" not in body and "reference_solution" not in body and "entry_point" not in body


def test_generate_endpoint_validation_and_auth(auth_client, client):
    assert auth_client.post("/api/questions/generate", json={"difficulty": "nope"}).status_code == 422
    assert auth_client.post("/api/questions/generate", json={"difficulty": "easy", "topic": "nope"}).status_code == 422
    client.headers.pop("Authorization", None)
    assert client.post("/api/questions/generate", json={"difficulty": "easy"}).status_code == 401


def test_topics_endpoint(auth_client):
    r = auth_client.get("/api/topics")
    assert r.status_code == 200
    assert {t["id"] for t in r.json()} == set(TOPICS)
