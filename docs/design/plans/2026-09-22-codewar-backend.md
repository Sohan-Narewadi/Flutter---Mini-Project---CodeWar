# CodeWar Backend Implementation Plan


**Goal:** Build the FastAPI backend the Flutter frontend (`frontend/codewar/`) already expects, so battles can actually be played instead of throwing "no backend level to battle against".

**Architecture:** FastAPI + SQLAlchemy + SQLite (`backend/codewar.db`), one router module per resource, a subprocess-based judge for Python/TypeScript code execution, seeded on first run with content matching `frontend/codewar/lib/services/seed_data.dart`.

**Tech Stack:** Python (3.14 confirmed installed), FastAPI, SQLAlchemy 2.x, Pydantic v2, Uvicorn, pytest + httpx (for `TestClient`). Judge subprocess calls out to the system `python` and `node` (Node 24 confirmed installed, runs `.ts` files directly via native type stripping — no `tsc`/`ts-node` needed).

**Spec:** `docs/design/specs/2026-09-22-codewar-backend-design.md`

## Global Constraints

- All JSON field names are `snake_case`, exactly matching every `fromJson` in `frontend/codewar/lib/models/*.dart` — this is not stylistic, the frontend will silently mis-parse on any mismatch.
- Single `Player` row, `id=1` — no auth, no multi-user.
- Error response body is always `{"detail": "<message>"}` (FastAPI's `HTTPException` default — do not override).
- CORS: `allow_origins=["*"]` (local single-user demo, no cookie/session auth to leak).
- Judge supports `python` and `typescript` only; `language == "cpp"` (or anything else) returns HTTP 400 with a "not supported" detail, no subprocess spawned.
- Judge is a timeout-bounded subprocess sandbox (5s/case), **not** OS-level isolation — this must be stated in `backend/README.md`, not just this plan.
- Run backend from `backend/` with `uvicorn app.main:app --host 0.0.0.0 --port 8000` (binding `0.0.0.0` makes it reachable as both `127.0.0.1`/`localhost` and, for the Android emulator, `10.0.2.2` — the frontend's default `ApiService.baseUrl`).

---

## Task 1: Project scaffolding — FastAPI app, DB session, health check

**Files:**
- Create: `backend/requirements.txt`
- Create: `backend/app/__init__.py` (empty)
- Create: `backend/app/database.py`
- Create: `backend/app/main.py`
- Test: `backend/tests/__init__.py` (empty)
- Test: `backend/tests/conftest.py`
- Test: `backend/tests/test_health.py`

**Interfaces:**
- Produces: `app.database.Base` (declarative base), `app.database.engine`, `app.database.SessionLocal`, `app.database.get_db()` (FastAPI dependency, yields a `Session`) — every later model/router imports these.
- Produces: `app.main.app` (the `FastAPI` instance) — every later router is included on this.
- Produces: `tests/conftest.py`'s `client` fixture (a `TestClient` with `get_db` overridden to an isolated in-memory SQLite DB per test) — every later test file uses this fixture.

- [ ] **Step 1: Create `backend/requirements.txt`**

```
fastapi>=0.115
uvicorn[standard]>=0.32
sqlalchemy>=2.0
pydantic>=2.9
pytest>=8.3
httpx>=0.27
```

- [ ] **Step 2: Install dependencies**

Run (from `backend/`, creating the directory first if needed):
```bash
mkdir -p backend && cd backend
python -m venv .venv
.venv/Scripts/python -m pip install -r requirements.txt
```
(On Windows, `.venv/Scripts/python`; on POSIX, `.venv/bin/python`. All later commands in this plan assume this venv's `python`/`pytest` are on `PATH` or invoked via this same path.)

- [ ] **Step 3: Write `backend/app/database.py`**

```python
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

DATABASE_URL = "sqlite:///./codewar.db"

engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

- [ ] **Step 4: Write `backend/app/main.py`**

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import Base, engine

app = FastAPI(title="CodeWar Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def on_startup():
    Base.metadata.create_all(bind=engine)


@app.get("/health")
def health():
    return {"status": "ok"}
```

- [ ] **Step 5: Write `backend/tests/conftest.py`**

```python
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app


@pytest.fixture()
def client():
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool,
    )
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)

    def override_get_db():
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        c.SessionLocal = TestingSessionLocal
        yield c
    app.dependency_overrides.clear()
```

- [ ] **Step 6: Write the failing test `backend/tests/test_health.py`**

```python
def test_health(client):
    res = client.get("/health")
    assert res.status_code == 200
    assert res.json() == {"status": "ok"}
```

- [ ] **Step 7: Run test to verify it fails (or passes — this is the first real test, just confirm it collects and runs)**

Run (from `backend/`): `pytest tests/test_health.py -v`
Expected: PASS (this task has no red-then-green step since there's no prior broken state — confirm it runs clean).

- [ ] **Step 8: Commit**

```bash
git add backend/requirements.txt backend/app/__init__.py backend/app/database.py backend/app/main.py backend/tests/__init__.py backend/tests/conftest.py backend/tests/test_health.py
git commit -m "backend: scaffold FastAPI app with health check"
```

---

## Task 2: SQLAlchemy models

**Files:**
- Create: `backend/app/models/__init__.py`
- Create: `backend/app/models/player.py`
- Create: `backend/app/models/world.py`
- Create: `backend/app/models/level.py`
- Create: `backend/app/models/enemy.py`
- Create: `backend/app/models/question.py`
- Create: `backend/app/models/battle.py`
- Test: `backend/tests/test_models.py`

**Interfaces:**
- Consumes: `app.database.Base` (Task 1).
- Produces: ORM classes `Player`, `World`, `Level`, `Enemy`, `Question`, `Battle` (all importable from `app.models`) — every later schema/router/seed file uses these. Exact columns listed below; later tasks read/write these attribute names verbatim.

- [ ] **Step 1: Write `backend/app/models/player.py`**

```python
from sqlalchemy import Column, Integer, String
from app.database import Base


class Player(Base):
    __tablename__ = "players"

    id = Column(Integer, primary_key=True)
    username = Column(String, nullable=False)
    display_name = Column(String, nullable=False)
    level = Column(Integer, nullable=False, default=1)
    xp = Column(Integer, nullable=False, default=0)
    xp_to_next = Column(Integer, nullable=False, default=1000)
    hp = Column(Integer, nullable=False, default=100)
    hp_max = Column(Integer, nullable=False, default=100)
    gold = Column(Integer, nullable=False, default=0)
    streak = Column(Integer, nullable=False, default=0)
```

- [ ] **Step 2: Write `backend/app/models/world.py`**

```python
from sqlalchemy import Column, Integer, String
from app.database import Base


class World(Base):
    __tablename__ = "worlds"

    id = Column(String, primary_key=True)
    name = Column(String, nullable=False)
    order = Column(Integer, nullable=False)
    description = Column(String, nullable=False, default="")
    cleared_percent = Column(Integer, nullable=False, default=0)
```

- [ ] **Step 3: Write `backend/app/models/level.py`**

```python
from sqlalchemy import Column, Integer, String
from app.database import Base


class Level(Base):
    __tablename__ = "levels"

    id = Column(Integer, primary_key=True)
    world_id = Column(String, nullable=False)
    order = Column(Integer, nullable=False)
    title = Column(String, nullable=False)
    difficulty = Column(String, nullable=False)
    status = Column(String, nullable=False, default="locked")
    stars = Column(Integer, nullable=False, default=0)
    enemy_id = Column(String, nullable=False)
    xp_reward = Column(Integer, nullable=False, default=0)
    gold_reward = Column(Integer, nullable=False, default=0)
    question_id = Column(String, nullable=False)
```

- [ ] **Step 4: Write `backend/app/models/enemy.py`**

```python
from sqlalchemy import Column, Integer, String, Boolean
from app.database import Base


class Enemy(Base):
    __tablename__ = "enemies"

    id = Column(String, primary_key=True)
    name = Column(String, nullable=False)
    level = Column(Integer, nullable=False)
    difficulty = Column(String, nullable=False)
    hp_max = Column(Integer, nullable=False)
    hp_current = Column(Integer, nullable=False)
    vulnerability = Column(String, nullable=False, default="")
    tier = Column(String, nullable=False, default="minion")
    locked = Column(Boolean, nullable=False, default=False)
    unlock_hint = Column(String, nullable=False, default="")
    xp_reward = Column(Integer, nullable=False, default=0)
    gold_reward = Column(Integer, nullable=False, default=0)
```

- [ ] **Step 5: Write `backend/app/models/question.py`**

```python
from sqlalchemy import Column, String, JSON
from app.database import Base


class Question(Base):
    __tablename__ = "questions"

    id = Column(String, primary_key=True)
    title = Column(String, nullable=False)
    difficulty = Column(String, nullable=False)
    tags = Column(JSON, nullable=False, default=list)
    prompt = Column(String, nullable=False)
    example_input = Column(String, nullable=False, default="")
    example_output = Column(String, nullable=False, default="")
    starter_code = Column(JSON, nullable=False, default=dict)
    test_cases = Column(JSON, nullable=False, default=list)
    entry_point = Column(JSON, nullable=False, default=dict)
    judge_cases = Column(JSON, nullable=False, default=list)
```

- [ ] **Step 6: Write `backend/app/models/battle.py`**

```python
from sqlalchemy import Column, Integer, String, DateTime
from app.database import Base


class Battle(Base):
    __tablename__ = "battles"

    id = Column(Integer, primary_key=True)
    level_id = Column(Integer, nullable=False)
    enemy_id = Column(String, nullable=False)
    question_id = Column(String, nullable=False)
    status = Column(String, nullable=False, default="in_progress")
    started_at = Column(DateTime, nullable=False)
    time_limit_s = Column(Integer, nullable=False, default=300)
    enemy_hp_remaining = Column(Integer, nullable=False)
    enemy_hp_max = Column(Integer, nullable=False)
    best_score_percent = Column(Integer, nullable=False, default=0)
```

- [ ] **Step 7: Write `backend/app/models/__init__.py`**

```python
from app.models.player import Player
from app.models.world import World
from app.models.level import Level
from app.models.enemy import Enemy
from app.models.question import Question
from app.models.battle import Battle

__all__ = ["Player", "World", "Level", "Enemy", "Question", "Battle"]
```

- [ ] **Step 8: Write the failing test `backend/tests/test_models.py`**

```python
from app.models import Player


def test_insert_and_query_player(client):
    db = client.SessionLocal()
    db.add(Player(
        id=1, username="codeknight", display_name="CodeKnight",
        level=12, xp=600, xp_to_next=1000, hp=800, hp_max=1000, gold=1240, streak=7,
    ))
    db.commit()
    db.close()

    db = client.SessionLocal()
    player = db.query(Player).filter(Player.id == 1).first()
    assert player.username == "codeknight"
    assert player.level == 12
    db.close()
```

- [ ] **Step 9: Run test to verify it fails**

Run: `pytest tests/test_models.py -v`
Expected: FAIL — `Player` table doesn't exist yet in the test DB because `app.models` was never imported before `Base.metadata.create_all` ran in `conftest.py` (SQLAlchemy only knows about tables whose model classes have been imported).

- [ ] **Step 10: Fix by importing models in conftest before create_all**

Modify `backend/tests/conftest.py` — add near the top imports:

```python
from app import models  # noqa: F401 (registers all models with Base.metadata)
```

- [ ] **Step 11: Run test to verify it passes**

Run: `pytest tests/ -v`
Expected: PASS (all tests so far, including `test_health.py`).

- [ ] **Step 12: Commit**

```bash
git add backend/app/models backend/tests/conftest.py backend/tests/test_models.py
git commit -m "backend: add SQLAlchemy models for Player, World, Level, Enemy, Question, Battle"
```

---

## Task 3: Pydantic schemas

**Files:**
- Create: `backend/app/schemas.py`
- Test: `backend/tests/test_schemas.py`

**Interfaces:**
- Consumes: nothing from earlier tasks (schemas are pure Pydantic, validated independently in this task's test; ORM wiring is exercised later once routers exist).
- Produces: `PlayerOut`, `WorldOut`, `LevelOut`, `EnemyOut`, `TestCaseOut`, `QuestionOut`, `BattleStartIn`, `BattleStartOut`, `CodeSubmitIn`, `TestResultOut`, `BattleRunOut`, `BattleSubmitOut` — every router in Tasks 7-10 imports these by exact name.

- [ ] **Step 1: Write `backend/app/schemas.py`**

```python
from pydantic import BaseModel, ConfigDict


class PlayerOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    username: str
    display_name: str
    level: int
    xp: int
    xp_to_next: int
    hp: int
    hp_max: int
    gold: int
    streak: int


class WorldOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    name: str
    order: int
    description: str
    cleared_percent: int


class LevelOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    world_id: str
    order: int
    title: str
    difficulty: str
    status: str
    stars: int
    enemy_id: str
    xp_reward: int
    gold_reward: int


class EnemyOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    name: str
    level: int
    difficulty: str
    hp_max: int
    hp_current: int
    vulnerability: str
    tier: str
    locked: bool
    unlock_hint: str
    xp_reward: int
    gold_reward: int


class TestCaseOut(BaseModel):
    input: str
    expected_output: str


class QuestionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    title: str
    difficulty: str
    tags: list[str]
    prompt: str
    example_input: str
    example_output: str
    starter_code: dict[str, str]
    test_cases: list[TestCaseOut]


class BattleStartIn(BaseModel):
    level_id: int


class BattleStartOut(BaseModel):
    battle_id: int
    enemy_hp_remaining: int
    time_limit_s: int
    started_at: str
    question: QuestionOut


class CodeSubmitIn(BaseModel):
    code: str
    language: str = "python"


class TestResultOut(BaseModel):
    input: str
    expected: str
    actual: str
    passed: bool
    duration_ms: float


class BattleRunOut(BaseModel):
    passed_tests: int
    total_tests: int
    results: list[TestResultOut]
    correctness_percent: int


class BattleSubmitOut(BattleRunOut):
    outcome: str
    xp_earned: int = 0
    gold_earned: int = 0
    hp_lost: int = 0
    damage_dealt: int = 0
    enemy_hp_remaining: int = 0
    enemy_hp_max: int = 0
    enemy_defeated: bool = False
    is_new_best: bool = False
    best_score_percent: int = 0
```

- [ ] **Step 2: Write the failing test `backend/tests/test_schemas.py`**

```python
from app.models import Question
from app.schemas import QuestionOut, PlayerOut
from app.models import Player


def test_question_out_from_orm_object():
    q = Question(
        id="q_find_max", title="Find Maximum Element", difficulty="Easy",
        tags=["Arrays"], prompt="p", example_input="in", example_output="out",
        starter_code={"python": "code"},
        test_cases=[{"input": "[1,2]", "expected_output": "2"}],
        entry_point={"python": "find_maximum"}, judge_cases=[{"args": [[1, 2]], "expected": 2}],
    )
    out = QuestionOut.model_validate(q)
    assert out.id == "q_find_max"
    assert out.test_cases[0].expected_output == "2"
    # backend-only fields must not leak into the API shape
    assert not hasattr(out, "entry_point")
    assert not hasattr(out, "judge_cases")


def test_player_out_from_orm_object():
    p = Player(id=1, username="codeknight", display_name="CodeKnight", level=12,
               xp=600, xp_to_next=1000, hp=800, hp_max=1000, gold=1240, streak=7)
    out = PlayerOut.model_validate(p)
    assert out.username == "codeknight"
```

- [ ] **Step 3: Run test to verify it fails**

Run: `pytest tests/test_schemas.py -v`
Expected: FAIL — `app.schemas` doesn't exist yet.

- [ ] **Step 4: Run test to verify it passes**

(Step 1 already wrote the implementation — this confirms it.)
Run: `pytest tests/ -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/app/schemas.py backend/tests/test_schemas.py
git commit -m "backend: add Pydantic I/O schemas"
```

---

## Task 4: Judge engine — Python execution

**Files:**
- Create: `backend/app/judge.py`
- Test: `backend/tests/test_judge.py`

**Interfaces:**
- Consumes: nothing (judge.py is a standalone subprocess-execution module).
- Produces: `run_case(language: str, code: str, entry_point: str, args: list, expected) -> dict` (returns `{"actual": str, "passed": bool, "duration_ms": float}`), `run_all_cases(language: str, code: str, entry_point: str, judge_cases: list[dict]) -> list[dict]`, `UnsupportedLanguageError` exception class — the battles router (Task 9/10) calls `run_all_cases` by this exact name/signature.

- [ ] **Step 1: Write the failing tests `backend/tests/test_judge.py`**

```python
import pytest
from app.judge import run_case, UnsupportedLanguageError

PY_ADD = "def add(a, b):\n    return a + b"


def test_python_pass():
    result = run_case("python", PY_ADD, "add", [2, 3], 5)
    assert result["passed"] is True
    assert result["actual"] == "5"


def test_python_fail():
    result = run_case("python", "def add(a, b):\n    return a - b", "add", [2, 3], 5)
    assert result["passed"] is False


def test_python_timeout():
    result = run_case("python", "def add(a, b):\n    while True:\n        pass", "add", [2, 3], 5)
    assert result["passed"] is False
    assert "Timed out" in result["actual"]


def test_python_syntax_error():
    result = run_case("python", "def add(a, b) return a + b", "add", [2, 3], 5)
    assert result["passed"] is False
    assert result["actual"] != ""


def test_unsupported_language():
    with pytest.raises(UnsupportedLanguageError):
        run_case("cpp", "int x;", "add", [2, 3], 5)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest tests/test_judge.py -v`
Expected: FAIL — `app.judge` doesn't exist yet.

- [ ] **Step 3: Write `backend/app/judge.py`**

```python
import json
import subprocess
import sys
import tempfile
import time
from pathlib import Path

TIMEOUT_S = 5

SUPPORTED_LANGUAGES = {"python", "typescript"}

PYTHON_HARNESS = """

import json as __json, sys as __sys
with open(__sys.argv[1]) as __f:
    __args = __json.load(__f)
print(__json.dumps({entry_point}(*__args)))
"""

TS_HARNESS = """

import {{ readFileSync }} from "node:fs";
const __args = JSON.parse(readFileSync(process.argv[2], "utf-8"));
console.log(JSON.stringify({entry_point}(...__args)));
"""


class UnsupportedLanguageError(Exception):
    pass


def run_case(language: str, code: str, entry_point: str, args: list, expected) -> dict:
    """Runs one test case in a fresh subprocess.

    Returns {"actual": str, "passed": bool, "duration_ms": float}. Never
    raises for a failing/crashing/timing-out submission — only for a
    genuinely unsupported language, which the caller should turn into an
    HTTP 400 before any subprocess is spawned.
    """
    if language not in SUPPORTED_LANGUAGES:
        raise UnsupportedLanguageError(f"Language '{language}' is not supported by the judge.")

    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        args_path = tmp / "args.json"
        args_path.write_text(json.dumps(args))

        if language == "python":
            source_path = tmp / "solution.py"
            source_path.write_text(code + PYTHON_HARNESS.format(entry_point=entry_point))
            command = [sys.executable, str(source_path), str(args_path)]
        else:
            source_path = tmp / "solution.ts"
            source_path.write_text(code + TS_HARNESS.format(entry_point=entry_point))
            command = ["node", str(source_path), str(args_path)]

        start = time.monotonic()
        try:
            proc = subprocess.run(
                command, capture_output=True, text=True, timeout=TIMEOUT_S, cwd=tmpdir,
            )
        except subprocess.TimeoutExpired:
            duration_ms = (time.monotonic() - start) * 1000
            return {"actual": f"Timed out after {TIMEOUT_S}s", "passed": False, "duration_ms": duration_ms}
        duration_ms = (time.monotonic() - start) * 1000

        if proc.returncode != 0:
            error_line = next((l for l in reversed(proc.stderr.splitlines()) if l.strip()), "Unknown error")
            return {"actual": error_line[:300], "passed": False, "duration_ms": duration_ms}

        output_lines = [l for l in proc.stdout.splitlines() if l.strip()]
        if not output_lines:
            return {"actual": "(no output)", "passed": False, "duration_ms": duration_ms}

        raw = output_lines[-1]
        try:
            actual_value = json.loads(raw)
        except json.JSONDecodeError:
            return {"actual": raw[:300], "passed": False, "duration_ms": duration_ms}

        return {"actual": raw, "passed": actual_value == expected, "duration_ms": duration_ms}


def run_all_cases(language: str, code: str, entry_point: str, judge_cases: list[dict]) -> list[dict]:
    return [
        run_case(language, code, entry_point, case["args"], case["expected"])
        for case in judge_cases
    ]
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/test_judge.py -v`
Expected: PASS (the timeout test takes ~5s — that's expected).

- [ ] **Step 5: Commit**

```bash
git add backend/app/judge.py backend/tests/test_judge.py
git commit -m "backend: add Python judge execution with timeout sandbox"
```

---

## Task 5: Judge engine — TypeScript execution

**Files:**
- Modify: `backend/tests/test_judge.py`

**Interfaces:**
- Consumes: `run_case` (Task 4) — no signature changes, this task only adds coverage for the `language == "typescript"` branch already written in Task 4's `judge.py`.
- Produces: nothing new (this task verifies existing code, matching the spec's call-out that TS support was confirmed locally with a throwaway `node file.ts` check before being designed in).

- [ ] **Step 1: Add the failing tests to `backend/tests/test_judge.py`**

Append:

```python
TS_ADD = "function add(a: number, b: number): number {\n  return a + b;\n}"


def test_typescript_pass():
    result = run_case("typescript", TS_ADD, "add", [2, 3], 5)
    assert result["passed"] is True
    assert result["actual"] == "5"


def test_typescript_fail():
    result = run_case("typescript", "function add(a: number, b: number): number {\n  return a - b;\n}", "add", [2, 3], 5)
    assert result["passed"] is False


def test_typescript_null_expected():
    code = "function findMaximum(nums: number[]): number | null {\n  if (nums.length === 0) return null;\n  return Math.max(...nums);\n}"
    result = run_case("typescript", code, "findMaximum", [[]], None)
    assert result["passed"] is True
```

- [ ] **Step 2: Run tests to verify current state**

Run: `pytest tests/test_judge.py -v`
Expected: PASS immediately — Task 4's `judge.py` already implements the `typescript` branch generically (same `run_case` function, just a different template/interpreter). This step exists to prove that branch is actually exercised by a real `node` subprocess, not just present in source.

If any of these fail, the likely cause is `node` not being on `PATH` for the test runner's environment — verify with `node --version` (this plan assumes the Node 24 already confirmed installed on this machine).

- [ ] **Step 3: Commit**

```bash
git add backend/tests/test_judge.py
git commit -m "backend: add TypeScript judge coverage"
```

---

## Task 6: Seed data

**Files:**
- Create: `backend/app/seed.py`
- Modify: `backend/tests/conftest.py`
- Test: `backend/tests/test_seed.py`

**Interfaces:**
- Consumes: `Player`, `World`, `Level`, `Enemy`, `Question` (Task 2).
- Produces: `seed_if_empty(db: Session) -> None` — called from `app.main`'s startup event (Task 7) and from `conftest.py`'s `client` fixture (this task) so every later test starts with realistic seeded data.

- [ ] **Step 1: Write `backend/app/seed.py`**

```python
from sqlalchemy.orm import Session

from app.models.player import Player
from app.models.world import World
from app.models.level import Level
from app.models.enemy import Enemy
from app.models.question import Question


def seed_if_empty(db: Session) -> None:
    if db.query(Player).first() is not None:
        return

    db.add(Player(
        id=1, username="codeknight", display_name="CodeKnight",
        level=12, xp=600, xp_to_next=1000, hp=800, hp_max=1000, gold=1240, streak=7,
    ))

    db.add(World(
        id="w2", name="Array Ruins", order=2,
        description="Sector 2 \u00b7 Corrupted array structures roam these ruins.",
        cleared_percent=50,
    ))

    db.add(Question(
        id="q_find_max", title="Find Maximum Element", difficulty="Easy",
        tags=["Arrays", "Two Pointers"],
        prompt="Given an integer array nums, return the greatest integer. Optimize for O(n) time and O(1) space.",
        example_input="nums = [3, 7, 2, 9, 4]", example_output="9",
        starter_code={
            "python": (
                "def find_maximum(nums: list[int]) -> int:\n"
                "    if not nums:\n"
                "        return 0  # <- Bug: Return None\n"
                "    max_val = nums[0]\n"
                "    for n in nums:\n"
                "        if n > max_val:\n"
                "            max_val = n\n"
                "    return max_val"
            ),
            "typescript": (
                "function findMaximum(nums: number[]): number {\n"
                "  if (nums.length === 0) {\n"
                "    return 0; // <- Bug: Return None/null\n"
                "  }\n"
                "  let maxVal = nums[0];\n"
                "  for (const n of nums) {\n"
                "    if (n > maxVal) maxVal = n;\n"
                "  }\n"
                "  return maxVal;\n"
                "}"
            ),
        },
        test_cases=[
            {"input": "[3, 7, 2, 9, 4]", "expected_output": "9"},
            {"input": "[-5, -1, -12]", "expected_output": "-1"},
            {"input": "[]", "expected_output": "None"},
        ],
        entry_point={"python": "find_maximum", "typescript": "findMaximum"},
        judge_cases=[
            {"args": [[3, 7, 2, 9, 4]], "expected": 9},
            {"args": [[-5, -1, -12]], "expected": -1},
            {"args": [[]], "expected": None},
        ],
    ))

    db.add(Question(
        id="q_two_sum", title="Two Sum Encounter", difficulty="Medium",
        tags=["Arrays", "Hash Map"],
        prompt=(
            "Given an array of integers nums and an integer target, return indices of the "
            "two numbers such that they add up to target. Assume exactly one solution exists, "
            "and you may not use the same element twice."
        ),
        example_input="nums = [2, 7, 11, 15], target = 9", example_output="[0, 1]",
        starter_code={
            "python": "def two_sum(nums: list[int], target: int) -> list[int]:\n    pass",
            "typescript": (
                "function twoSum(nums: number[], target: number): number[] {\n"
                "  const seen = new Map<number, number>();\n"
                "  for (let i = 0; i < nums.length; i++) {\n"
                "    const complement = target - nums[i];\n"
                "    if (seen.has(complement)) return [seen.get(complement)!, i];\n"
                "    seen.set(nums[i], i);\n"
                "  }\n"
                "  return [];\n"
                "}"
            ),
        },
        test_cases=[
            {"input": "nums = [2, 7, 11, 15], target = 9", "expected_output": "[0, 1]"},
            {"input": "nums = [3, 2, 4], target = 6", "expected_output": "[1, 2]"},
            {"input": "nums = [3, 3], target = 6", "expected_output": "[0, 1]"},
        ],
        entry_point={"python": "two_sum", "typescript": "twoSum"},
        judge_cases=[
            {"args": [[2, 7, 11, 15], 9], "expected": [0, 1]},
            {"args": [[3, 2, 4], 6], "expected": [1, 2]},
            {"args": [[3, 3], 6], "expected": [0, 1]},
        ],
    ))

    levels = [
        Level(id=1, world_id="w2", order=1, title="Syntax Verification", difficulty="easy",
              status="completed", stars=3, enemy_id="e_syntax_snake", xp_reward=80, gold_reward=30,
              question_id="q_find_max"),
        Level(id=2, world_id="w2", order=2, title="Array Basics & Traversal", difficulty="easy",
              status="completed", stars=3, enemy_id="e_bug_bot", xp_reward=90, gold_reward=35,
              question_id="q_find_max"),
        Level(id=3, world_id="w2", order=3, title="Find Maximum Element", difficulty="easy",
              status="completed", stars=3, enemy_id="e_array_beast", xp_reward=100, gold_reward=40,
              question_id="q_find_max"),
        Level(id=4, world_id="w2", order=4, title="Two Sum Encounter", difficulty="medium",
              status="current", stars=0, enemy_id="e_array_beast", xp_reward=250, gold_reward=100,
              question_id="q_two_sum"),
        Level(id=5, world_id="w2", order=5, title="Binary Search Protocol", difficulty="medium",
              status="locked", stars=0, enemy_id="e_string_samurai", xp_reward=220, gold_reward=90,
              question_id="q_two_sum"),
        Level(id=6, world_id="w2", order=6, title="Sliding Window Trap", difficulty="medium",
              status="locked", stars=0, enemy_id="e_string_samurai", xp_reward=230, gold_reward=95,
              question_id="q_two_sum"),
        Level(id=7, world_id="w2", order=7, title="Merge Intervals", difficulty="hard",
              status="locked", stars=0, enemy_id="e_recursion_zombie", xp_reward=350, gold_reward=150,
              question_id="q_two_sum"),
        Level(id=8, world_id="w2", order=8, title="Array Beast Overlord", difficulty="boss",
              status="locked", stars=0, enemy_id="e_algorithm_dragon", xp_reward=1500, gold_reward=500,
              question_id="q_two_sum"),
    ]
    for level in levels:
        db.add(level)

    enemies = [
        Enemy(id="e_array_beast", name="Array Beast", level=10, difficulty="medium", hp_max=1000,
              hp_current=720, vulnerability="Arrays / Hash Map", tier="minion", locked=False,
              unlock_hint="", xp_reward=250, gold_reward=100),
        Enemy(id="e_syntax_snake", name="Syntax Snake", level=4, difficulty="easy", hp_max=450,
              hp_current=450, vulnerability="Strings", tier="minion", locked=False,
              unlock_hint="", xp_reward=80, gold_reward=30),
        Enemy(id="e_bug_bot", name="Bug Bot", level=6, difficulty="easy", hp_max=600,
              hp_current=0, vulnerability="Loops", tier="minion", locked=False,
              unlock_hint="", xp_reward=60, gold_reward=25),
        Enemy(id="e_string_samurai", name="String Samurai", level=12, difficulty="medium", hp_max=1200,
              hp_current=1200, vulnerability="Two Pointers", tier="minion", locked=False,
              unlock_hint="", xp_reward=380, gold_reward=180),
        Enemy(id="e_recursion_zombie", name="Recursion Zombie", level=16, difficulty="hard", hp_max=2000,
              hp_current=2000, vulnerability="Stack Memory", tier="minion", locked=True,
              unlock_hint="Unlock: reach World 2 Boss", xp_reward=500, gold_reward=220),
        Enemy(id="e_algorithm_dragon", name="Algorithm Dragon", level=25, difficulty="boss", hp_max=5000,
              hp_current=5000, vulnerability="Dynamic Programming", tier="boss", locked=True,
              unlock_hint="Unlock: defeat 6 sector minions", xp_reward=1500, gold_reward=500),
    ]
    for enemy in enemies:
        db.add(enemy)

    db.commit()
```

- [ ] **Step 2: Modify `backend/tests/conftest.py` to seed on every test**

Add the import near the top:
```python
from app.seed import seed_if_empty
```

In the `client` fixture, right after `Base.metadata.create_all(bind=engine)`, add:
```python
    seed_db = TestingSessionLocal()
    seed_if_empty(seed_db)
    seed_db.close()
```

- [ ] **Step 3: Write the failing test `backend/tests/test_seed.py`**

```python
from app.models import Player, World, Level, Enemy, Question


def test_seed_creates_expected_counts(client):
    db = client.SessionLocal()
    assert db.query(Player).count() == 1
    assert db.query(World).count() == 1
    assert db.query(Level).count() == 8
    assert db.query(Enemy).count() == 6
    assert db.query(Question).count() == 2
    db.close()


def test_seed_is_idempotent(client):
    from app.seed import seed_if_empty
    db = client.SessionLocal()
    seed_if_empty(db)  # second call, DB already has a Player row
    assert db.query(Level).count() == 8  # unchanged, not doubled
    db.close()


def test_level_ids_are_integers_for_battle_start(client):
    # This is the exact bug this backend fixes: seed_data.dart's ids ("n1".."n8")
    # aren't parseable as int, so GameState.startBattle() always threw
    # "This encounter has no backend level to battle against." Real backend
    # level ids must be plain integers.
    db = client.SessionLocal()
    level = db.query(Level).filter(Level.order == 3).first()
    assert isinstance(level.id, int)
    db.close()
```

- [ ] **Step 4: Run tests to verify they fail, then pass**

Run: `pytest tests/test_seed.py -v`
Expected first: FAIL (`app.seed` doesn't exist before Step 1 is applied — since Step 1 already wrote it, this instead confirms the fixture wiring from Step 2 is required: temporarily comment out the `seed_if_empty` calls in `conftest.py` to see the expected-failure state, then restore them).
Expected after Steps 1-2 are in place: PASS.

Run full suite to confirm no regressions: `pytest tests/ -v`

- [ ] **Step 5: Commit**

```bash
git add backend/app/seed.py backend/tests/conftest.py backend/tests/test_seed.py
git commit -m "backend: seed DB with Array Ruins content matching seed_data.dart"
```

---

## Task 7: Read-only routers (player, worlds, levels, enemies, questions)

**Files:**
- Create: `backend/app/routers/__init__.py` (empty)
- Create: `backend/app/routers/player.py`
- Create: `backend/app/routers/worlds.py`
- Create: `backend/app/routers/levels.py`
- Create: `backend/app/routers/enemies.py`
- Create: `backend/app/routers/questions.py`
- Modify: `backend/app/main.py`
- Test: `backend/tests/test_read_endpoints.py`

**Interfaces:**
- Consumes: models (Task 2), schemas (Task 3), `get_db` (Task 1).
- Produces: registers `GET /api/player`, `GET /api/worlds`, `GET /api/levels?world_id=`, `GET /api/enemies`, `GET /api/questions/{id}` on `app.main.app`.

- [ ] **Step 1: Write the failing tests `backend/tests/test_read_endpoints.py`**

```python
def test_get_player(client):
    res = client.get("/api/player")
    assert res.status_code == 200
    body = res.json()
    assert body["username"] == "codeknight"
    assert body["level"] == 12


def test_get_worlds(client):
    res = client.get("/api/worlds")
    assert res.status_code == 200
    body = res.json()
    assert len(body) == 1
    assert body[0]["id"] == "w2"


def test_get_levels_for_world(client):
    res = client.get("/api/levels", params={"world_id": "w2"})
    assert res.status_code == 200
    body = res.json()
    assert len(body) == 8
    assert body[0]["title"] == "Syntax Verification"
    assert "question_id" not in body[0]


def test_get_enemies(client):
    res = client.get("/api/enemies")
    assert res.status_code == 200
    assert len(res.json()) == 6


def test_get_question_by_id(client):
    res = client.get("/api/questions/q_two_sum")
    assert res.status_code == 200
    assert res.json()["title"] == "Two Sum Encounter"


def test_get_question_unknown_id(client):
    res = client.get("/api/questions/nope")
    assert res.status_code == 404
    assert "detail" in res.json()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest tests/test_read_endpoints.py -v`
Expected: FAIL with 404s (routes don't exist yet).

- [ ] **Step 3: Write `backend/app/routers/player.py`**

```python
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.player import Player
from app.schemas import PlayerOut

router = APIRouter()


@router.get("/api/player", response_model=PlayerOut)
def get_player(db: Session = Depends(get_db)):
    return db.query(Player).filter(Player.id == 1).first()
```

- [ ] **Step 4: Write `backend/app/routers/worlds.py`**

```python
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.world import World
from app.schemas import WorldOut

router = APIRouter()


@router.get("/api/worlds", response_model=list[WorldOut])
def list_worlds(db: Session = Depends(get_db)):
    return db.query(World).order_by(World.order).all()
```

- [ ] **Step 5: Write `backend/app/routers/levels.py`**

```python
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.level import Level
from app.schemas import LevelOut

router = APIRouter()


@router.get("/api/levels", response_model=list[LevelOut])
def list_levels(world_id: str, db: Session = Depends(get_db)):
    return db.query(Level).filter(Level.world_id == world_id).order_by(Level.order).all()
```

- [ ] **Step 6: Write `backend/app/routers/enemies.py`**

```python
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.enemy import Enemy
from app.schemas import EnemyOut

router = APIRouter()


@router.get("/api/enemies", response_model=list[EnemyOut])
def list_enemies(db: Session = Depends(get_db)):
    return db.query(Enemy).all()
```

- [ ] **Step 7: Write `backend/app/routers/questions.py`**

```python
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.question import Question
from app.schemas import QuestionOut

router = APIRouter()


@router.get("/api/questions/{question_id}", response_model=QuestionOut)
def get_question(question_id: str, db: Session = Depends(get_db)):
    question = db.query(Question).filter(Question.id == question_id).first()
    if question is None:
        raise HTTPException(status_code=404, detail=f"Question '{question_id}' not found.")
    return question
```

- [ ] **Step 8: Modify `backend/app/main.py` to wire seeding + these routers**

Replace the whole file with:

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import Base, engine, SessionLocal
from app import models  # noqa: F401 (registers models with Base.metadata)
from app.seed import seed_if_empty
from app.routers import player, worlds, levels, enemies, questions

app = FastAPI(title="CodeWar Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(player.router)
app.include_router(worlds.router)
app.include_router(levels.router)
app.include_router(enemies.router)
app.include_router(questions.router)


@app.on_event("startup")
def on_startup():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        seed_if_empty(db)
    finally:
        db.close()


@app.get("/health")
def health():
    return {"status": "ok"}
```

- [ ] **Step 9: Run tests to verify they pass**

Run: `pytest tests/ -v`
Expected: PASS (all tests, including Tasks 1-6's).

- [ ] **Step 10: Commit**

```bash
git add backend/app/routers/__init__.py backend/app/routers/player.py backend/app/routers/worlds.py backend/app/routers/levels.py backend/app/routers/enemies.py backend/app/routers/questions.py backend/app/main.py backend/tests/test_read_endpoints.py
git commit -m "backend: add read-only routers for player, worlds, levels, enemies, questions"
```

---

## Task 8: Battle start endpoint

**Files:**
- Create: `backend/app/routers/battles.py`
- Modify: `backend/app/main.py`
- Test: `backend/tests/test_battles.py`

**Interfaces:**
- Consumes: `Battle`, `Level`, `Enemy`, `Question` models (Task 2); `BattleStartIn`, `BattleStartOut`, `QuestionOut` schemas (Task 3).
- Produces: `POST /api/battles/start`. Also produces the `router` object in `app/routers/battles.py` that Tasks 9-10 add endpoints to (same file, same `APIRouter()` instance).

- [ ] **Step 1: Write the failing tests `backend/tests/test_battles.py`**

```python
def test_start_battle_unknown_level(client):
    res = client.post("/api/battles/start", json={"level_id": 999})
    assert res.status_code == 404


def test_start_battle_known_level(client):
    res = client.post("/api/battles/start", json={"level_id": 3})
    assert res.status_code == 200
    body = res.json()
    assert body["battle_id"] > 0
    assert body["enemy_hp_remaining"] == 1000  # e_array_beast.hp_max
    assert body["time_limit_s"] == 300
    assert body["question"]["id"] == "q_find_max"  # level 3 -> q_find_max
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest tests/test_battles.py -v`
Expected: FAIL — route doesn't exist.

- [ ] **Step 3: Write `backend/app/routers/battles.py`**

```python
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.battle import Battle
from app.models.level import Level
from app.models.enemy import Enemy
from app.models.question import Question
from app.schemas import BattleStartIn, BattleStartOut, QuestionOut

router = APIRouter()


@router.post("/api/battles/start", response_model=BattleStartOut)
def start_battle(body: BattleStartIn, db: Session = Depends(get_db)):
    level = db.query(Level).filter(Level.id == body.level_id).first()
    if level is None:
        raise HTTPException(status_code=404, detail=f"Level {body.level_id} not found.")
    enemy = db.query(Enemy).filter(Enemy.id == level.enemy_id).first()
    question = db.query(Question).filter(Question.id == level.question_id).first()
    if enemy is None or question is None:
        raise HTTPException(status_code=404, detail="Level is missing its enemy or question.")

    started_at = datetime.now(timezone.utc)
    battle = Battle(
        level_id=level.id, enemy_id=enemy.id, question_id=question.id,
        status="in_progress", started_at=started_at, time_limit_s=300,
        enemy_hp_remaining=enemy.hp_max, enemy_hp_max=enemy.hp_max, best_score_percent=0,
    )
    db.add(battle)
    db.commit()
    db.refresh(battle)

    return BattleStartOut(
        battle_id=battle.id,
        enemy_hp_remaining=battle.enemy_hp_remaining,
        time_limit_s=battle.time_limit_s,
        started_at=started_at.isoformat(),
        question=QuestionOut.model_validate(question),
    )
```

- [ ] **Step 4: Modify `backend/app/main.py`**

Add `battles` to the router import line:
```python
from app.routers import player, worlds, levels, enemies, questions, battles
```
Add after the other `app.include_router(...)` lines:
```python
app.include_router(battles.router)
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `pytest tests/ -v`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add backend/app/routers/battles.py backend/app/main.py backend/tests/test_battles.py
git commit -m "backend: add POST /api/battles/start"
```

---

## Task 9: Battle run endpoint (judge preview, no state mutation)

**Files:**
- Modify: `backend/app/routers/battles.py`
- Modify: `backend/tests/test_battles.py`

**Interfaces:**
- Consumes: `run_all_cases`, `UnsupportedLanguageError` (Task 4/5); `CodeSubmitIn`, `BattleRunOut`, `TestResultOut` (Task 3).
- Produces: `POST /api/battles/{battle_id}/run`; a private `_judge(question, code, language)` helper in `battles.py` that Task 10's submit endpoint reuses (same file).

- [ ] **Step 1: Add the failing tests to `backend/tests/test_battles.py`**

Append:

```python
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


def test_run_battle_all_pass(client):
    start = client.post("/api/battles/start", json={"level_id": 3})
    battle_id = start.json()["battle_id"]

    res = client.post(f"/api/battles/{battle_id}/run", json={"code": CORRECT_FIND_MAX, "language": "python"})
    assert res.status_code == 200
    body = res.json()
    assert body["passed_tests"] == 3
    assert body["total_tests"] == 3
    assert body["correctness_percent"] == 100


def test_run_battle_does_not_mutate_enemy_hp(client):
    start = client.post("/api/battles/start", json={"level_id": 3})
    battle_id = start.json()["battle_id"]

    client.post(f"/api/battles/{battle_id}/run", json={"code": CORRECT_FIND_MAX, "language": "python"})

    submit = client.post(f"/api/battles/{battle_id}/submit", json={"code": CORRECT_FIND_MAX, "language": "python"})
    # If /run had already damaged the enemy, this first submit's damage would
    # land on a partially-depleted hp_remaining instead of the full hp_max.
    assert submit.json()["enemy_hp_remaining"] == 1000 - submit.json()["damage_dealt"]


def test_run_battle_unknown_battle(client):
    res = client.post("/api/battles/9999/run", json={"code": "x", "language": "python"})
    assert res.status_code == 404


def test_run_battle_unsupported_language(client):
    start = client.post("/api/battles/start", json={"level_id": 3})
    battle_id = start.json()["battle_id"]
    res = client.post(f"/api/battles/{battle_id}/run", json={"code": "int x;", "language": "cpp"})
    assert res.status_code == 400
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest tests/test_battles.py -v`
Expected: FAIL — `/run` route doesn't exist yet (the `submit` test in Step 1 will also fail until Task 10, which is expected at this point — note in the run log which failures are `/run`-specific and confirm those in Step 4).

- [ ] **Step 3: Modify `backend/app/routers/battles.py`**

Add these imports at the top (alongside the existing ones):
```python
from app.models.battle import Battle
from app.schemas import CodeSubmitIn, BattleRunOut, TestResultOut
from app.judge import run_all_cases, UnsupportedLanguageError
```

Add this helper and endpoint at the end of the file:

```python
def _judge(question: Question, code: str, language: str) -> tuple[list[TestResultOut], int, int]:
    try:
        entry_point = question.entry_point.get(language, "")
        results = run_all_cases(language, code, entry_point, question.judge_cases)
    except UnsupportedLanguageError as exc:
        raise HTTPException(status_code=400, detail=str(exc))

    display = question.test_cases
    out = [
        TestResultOut(
            input=display[i]["input"],
            expected=display[i]["expected_output"],
            actual=results[i]["actual"],
            passed=results[i]["passed"],
            duration_ms=results[i]["duration_ms"],
        )
        for i in range(len(results))
    ]
    passed_tests = sum(1 for r in out if r.passed)
    return out, passed_tests, len(out)


@router.post("/api/battles/{battle_id}/run", response_model=BattleRunOut)
def run_battle(battle_id: int, body: CodeSubmitIn, db: Session = Depends(get_db)):
    battle = db.query(Battle).filter(Battle.id == battle_id).first()
    if battle is None:
        raise HTTPException(status_code=404, detail=f"Battle {battle_id} not found.")
    question = db.query(Question).filter(Question.id == battle.question_id).first()

    results, passed_tests, total_tests = _judge(question, body.code, body.language)
    correctness_percent = round(100 * passed_tests / total_tests) if total_tests else 0

    return BattleRunOut(
        passed_tests=passed_tests, total_tests=total_tests, results=results,
        correctness_percent=correctness_percent,
    )
```

- [ ] **Step 4: Run tests to verify `/run` tests pass**

Run: `pytest tests/test_battles.py -k "run_battle" -v`
Expected: PASS for all `test_run_battle_*` tests. (`test_run_battle_does_not_mutate_enemy_hp` also calls `/submit`, which doesn't exist until Task 10 — expected to fail here; it's finalized in Task 10's own test run.)

- [ ] **Step 5: Commit**

```bash
git add backend/app/routers/battles.py backend/tests/test_battles.py
git commit -m "backend: add POST /api/battles/{id}/run (judge preview, no state mutation)"
```

---

## Task 10: Battle submit endpoint (game logic)

**Files:**
- Modify: `backend/app/routers/battles.py`
- Modify: `backend/tests/test_battles.py`

**Interfaces:**
- Consumes: `_judge` helper (Task 9); `Player` model (Task 2); `BattleSubmitOut` schema (Task 3).
- Produces: `POST /api/battles/{battle_id}/submit`.

- [ ] **Step 1: Add the failing tests to `backend/tests/test_battles.py`**

Append:

```python
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


def test_submit_partial_credit_does_not_finalize_and_damages_player(client):
    start = client.post("/api/battles/start", json={"level_id": 3})
    battle_id = start.json()["battle_id"]

    res = client.post(f"/api/battles/{battle_id}/submit", json={"code": BUGGY_FIND_MAX, "language": "python"})
    assert res.status_code == 200
    body = res.json()
    assert body["passed_tests"] == 2
    assert body["total_tests"] == 3
    assert body["outcome"] == "in_progress"
    assert body["hp_lost"] > 0
    assert body["damage_dealt"] > 0


def test_submit_full_credit_repeated_wins_and_rejects_resubmit(client):
    start = client.post("/api/battles/start", json={"level_id": 3})
    battle_id = start.json()["battle_id"]

    # e_array_beast hp_max=1000; damage per 100%-correct hit = ceil(1000/3) = 334
    r1 = client.post(f"/api/battles/{battle_id}/submit", json={"code": CORRECT_FIND_MAX, "language": "python"}).json()
    assert r1["outcome"] == "in_progress"
    assert r1["damage_dealt"] == 334
    assert r1["enemy_hp_remaining"] == 666

    r2 = client.post(f"/api/battles/{battle_id}/submit", json={"code": CORRECT_FIND_MAX, "language": "python"}).json()
    assert r2["enemy_hp_remaining"] == 332

    r3 = client.post(f"/api/battles/{battle_id}/submit", json={"code": CORRECT_FIND_MAX, "language": "python"}).json()
    assert r3["outcome"] == "won"
    assert r3["enemy_defeated"] is True
    assert r3["enemy_hp_remaining"] == 0
    assert r3["xp_earned"] == 100  # level 3 xp_reward
    assert r3["gold_earned"] == 40  # level 3 gold_reward

    resubmit = client.post(f"/api/battles/{battle_id}/submit", json={"code": CORRECT_FIND_MAX, "language": "python"})
    assert resubmit.status_code == 400


def test_submit_after_deadline_expires(client):
    from datetime import datetime, timedelta, timezone
    from app.models.battle import Battle

    start = client.post("/api/battles/start", json={"level_id": 3})
    battle_id = start.json()["battle_id"]

    db = client.SessionLocal()
    battle = db.query(Battle).filter(Battle.id == battle_id).first()
    battle.started_at = datetime.now(timezone.utc) - timedelta(seconds=400)
    db.commit()
    db.close()

    res = client.post(f"/api/battles/{battle_id}/submit", json={"code": CORRECT_FIND_MAX, "language": "python"})
    assert res.status_code == 200
    assert res.json()["outcome"] == "expired"


def test_submit_unknown_battle(client):
    res = client.post("/api/battles/9999/submit", json={"code": "x", "language": "python"})
    assert res.status_code == 404
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest tests/test_battles.py -k "submit" -v`
Expected: FAIL — `/submit` route doesn't exist yet.

- [ ] **Step 3: Modify `backend/app/routers/battles.py`**

`datetime` and `timezone` are already imported by Task 8's `from datetime import datetime, timezone` line at the top of this file — no change needed there. Add these new imports alongside it:
```python
import math
from app.models.player import Player
from app.schemas import BattleSubmitOut
```

Add this endpoint at the end of the file:

```python
@router.post("/api/battles/{battle_id}/submit", response_model=BattleSubmitOut)
def submit_battle(battle_id: int, body: CodeSubmitIn, db: Session = Depends(get_db)):
    battle = db.query(Battle).filter(Battle.id == battle_id).first()
    if battle is None:
        raise HTTPException(status_code=404, detail=f"Battle {battle_id} not found.")
    if battle.status != "in_progress":
        raise HTTPException(status_code=400, detail=f"Battle {battle_id} is already {battle.status}.")

    now = datetime.now(timezone.utc)
    started_at = battle.started_at
    if started_at.tzinfo is None:
        started_at = started_at.replace(tzinfo=timezone.utc)
    if (now - started_at).total_seconds() > battle.time_limit_s:
        battle.status = "expired"
        db.commit()
        return BattleSubmitOut(
            passed_tests=0, total_tests=0, results=[], correctness_percent=0,
            outcome="expired", enemy_hp_remaining=battle.enemy_hp_remaining,
            enemy_hp_max=battle.enemy_hp_max, best_score_percent=battle.best_score_percent,
        )

    question = db.query(Question).filter(Question.id == battle.question_id).first()
    results, passed_tests, total_tests = _judge(question, body.code, body.language)
    correctness_percent = round(100 * passed_tests / total_tests) if total_tests else 0

    damage_dealt = round(correctness_percent / 100 * math.ceil(battle.enemy_hp_max / 3))
    battle.enemy_hp_remaining = max(0, battle.enemy_hp_remaining - damage_dealt)
    enemy_defeated = battle.enemy_hp_remaining == 0

    player = db.query(Player).filter(Player.id == 1).first()
    hp_lost = round((100 - correctness_percent) / 100 * 10)
    player.hp = max(0, player.hp - hp_lost)

    is_new_best = correctness_percent > battle.best_score_percent
    if is_new_best:
        battle.best_score_percent = correctness_percent

    xp_earned = 0
    gold_earned = 0
    outcome = "in_progress"
    if enemy_defeated:
        outcome = "won"
        battle.status = "won"
        level = db.query(Level).filter(Level.id == battle.level_id).first()
        stars = 3 if correctness_percent == 100 else (2 if correctness_percent >= 70 else 1)
        level.status = "completed"
        if stars > level.stars:
            level.stars = stars
        xp_earned = level.xp_reward
        gold_earned = level.gold_reward
        player.xp += xp_earned
        player.gold += gold_earned
        while player.xp >= player.xp_to_next:
            player.xp -= player.xp_to_next
            player.level += 1
            player.xp_to_next = round(player.xp_to_next * 1.2)
    elif player.hp == 0:
        outcome = "lost"
        battle.status = "lost"

    db.commit()

    return BattleSubmitOut(
        passed_tests=passed_tests, total_tests=total_tests, results=results,
        correctness_percent=correctness_percent, outcome=outcome,
        xp_earned=xp_earned, gold_earned=gold_earned, hp_lost=hp_lost,
        damage_dealt=damage_dealt, enemy_hp_remaining=battle.enemy_hp_remaining,
        enemy_hp_max=battle.enemy_hp_max, enemy_defeated=enemy_defeated,
        is_new_best=is_new_best, best_score_percent=battle.best_score_percent,
    )
```

- [ ] **Step 4: Run the full test suite to verify everything passes**

Run: `pytest tests/ -v`
Expected: PASS — every test from Tasks 1-10, including the `test_run_battle_does_not_mutate_enemy_hp` test left pending since Task 9.

- [ ] **Step 5: Commit**

```bash
git add backend/app/routers/battles.py backend/tests/test_battles.py
git commit -m "backend: add POST /api/battles/{id}/submit with damage/xp/leveling game logic"
```

---

## Task 11: README, .gitignore, and manual end-to-end verification

**Files:**
- Create: `backend/README.md`
- Create: `backend/.gitignore`

**Interfaces:**
- Consumes: the fully assembled `app.main.app` (Tasks 1-10).
- Produces: nothing new in code — this task is documentation plus a manual smoke test against the already-running Flutter builds.

- [ ] **Step 1: Write `backend/.gitignore`**

```
.venv/
__pycache__/
*.pyc
codewar.db
```

- [ ] **Step 2: Write `backend/README.md`**

```markdown
# CodeWar Backend

FastAPI backend for the CodeWar Flutter app (`frontend/codewar/`).

## Run it

    cd backend
    python -m venv .venv
    .venv/Scripts/python -m pip install -r requirements.txt   # .venv/bin/python on POSIX
    .venv/Scripts/python -m uvicorn app.main:app --host 0.0.0.0 --port 8000

First run creates `codewar.db` (SQLite) and seeds it with the Array Ruins
world (8 levels, 6 enemies, 2 questions).

Binding `0.0.0.0` means the API is reachable as:
- `http://127.0.0.1:8000` or `http://localhost:8000` — Windows desktop and web builds
- `http://10.0.2.2:8000` — the Android emulator's alias for the host loopback,
  which is `ApiService`'s default `baseUrl` in the Flutter app

## Run the tests

    .venv/Scripts/python -m pytest tests/ -v

## Security note

The code judge (`app/judge.py`) runs submitted Python/TypeScript in a
timeout-bounded subprocess (5s per test case). This is adequate isolation
for a trusted local single-player demo but provides **no OS-level
sandboxing** (no containers, no seccomp, no network denial). Do not expose
this backend to untrusted users over a network as-is.

## Supported judge languages

- `python` (via the system `python`/`sys.executable`)
- `typescript` (via `node`, using Node's native TS type-stripping — no
  `tsc`/`ts-node` needed; requires Node 22.6+ for `--experimental-strip-types`
  or Node 23.6+/24+ where it's on by default)
- `cpp` starter code is shown in the editor but submissions return HTTP 400
  ("not supported") — no C++ compiler is assumed to be installed.
```

- [ ] **Step 3: Start the backend for manual verification**

Run (from `backend/`, foreground or background):
```bash
.venv/Scripts/python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

- [ ] **Step 4: Smoke-test with curl**

```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/api/player
curl http://127.0.0.1:8000/api/worlds
curl "http://127.0.0.1:8000/api/levels?world_id=w2"
curl -X POST http://127.0.0.1:8000/api/battles/start -H "Content-Type: application/json" -d "{\"level_id\": 3}"
```
Expected: all 200s, JSON bodies matching the shapes in Task 3/6.

- [ ] **Step 5: Play one real battle end-to-end on each already-running Flutter build**

For each of the Windows desktop build, the web build (`:8766`), and (once booted) the Android emulator build: open the app, go to Battle Arena, pick an available encounter, confirm the "no backend level to battle against" error is gone, run tests, submit until the enemy is defeated, confirm XP/gold update in Profile.

The Android emulator build must be freshly launched pointed at the running backend (`flutter run -d <emulator-id>` from `frontend/codewar/`) — its `ApiService` default `baseUrl` (`http://10.0.2.2:8000`) requires no code change since the backend is already bound to `0.0.0.0:8000`.

- [ ] **Step 6: Commit**

```bash
git add backend/README.md backend/.gitignore
git commit -m "backend: add README with run instructions and security note"
```
