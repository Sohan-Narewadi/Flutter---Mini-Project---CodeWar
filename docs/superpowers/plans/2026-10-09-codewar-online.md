# CodeWar Online Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **Resuming in a new session? Read `docs/superpowers/PROGRESS.md` first.**

**Goal:** Add accounts, unlimited generated questions, online Race/Duel rooms, a real leaderboard, a better Practice mode and a polished UI to CodeWar.

**Architecture:** FastAPI backend gains per-player auth (name + bearer token), a question engine (LLM + templates, judge-verified, cached), a room manager with WebSockets, and rating/leaderboard queries. The Flutter app gains a configurable API URL, onboarding, a design system, and lobby/race/duel screens.

**Tech Stack:** FastAPI, SQLAlchemy 2, SQLite, pytest, Starlette TestClient (WebSockets), Anthropic Python SDK (optional), Flutter 3 (provider, go_router, http, + shared_preferences, web_socket_channel).

**Spec:** `docs/superpowers/specs/2026-10-09-codewar-online-design.md`

## Global Constraints
- Backend root: `backend/`. Run tests with `cd backend && python -m pytest -q` (Python venv at `backend/.venv`). Flutter app: `frontend/codewar/` (`flutter test`, `flutter analyze`).
- All new backend code is TDD: failing test first, then implementation, then commit.
- Judge supports `python` and `typescript` only. C++ must not be offered in the UI.
- Expected outputs for generated questions are ALWAYS computed by running a reference solution through the judge; never trust LLM-supplied expected values.
- Server owns clock and scoring for rooms. Clients never claim results.
- Tokens are stored hashed (sha256) in the DB; raw token is returned exactly once.
- Display names: 2-16 chars, unique case-insensitively.
- Commit after every task. Commit trailer: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- After finishing each stage, update `docs/superpowers/PROGRESS.md` and commit.

## Review Focus
- Two players with the same name differing only by case -> second gets 409.
- Missing/invalid/garbled bearer token -> 401, never a 500 or acting as another player.
- Submitting to someone else's battle id -> 403/404.
- Offline/unreachable backend in the app -> visible banner, no fabricated data.
- LLM returns malformed JSON, a wrong reference solution, or times out -> falls back to a template, request still succeeds.
- Room: late joiner after start, host leaves, duplicate join, disconnect + reconnect within 30s, ties in Race ranking.

## Known facts about existing code (verified 2026-10-09)
- `backend/app/routers/battles.py` hardcodes `Player.id == 1`; `Level.status/stars` and enemy defeated state are GLOBAL (single-player). Multi-player requires moving them to per-player rows (Task 1.2).
- `backend/tests/conftest.py` `client` fixture seeds via `seed_if_empty` and overrides `get_db`; exposes `client.SessionLocal`.
- `app/seed.py::seed_if_empty` currently inserts `Player(id=1)`, worlds, levels, enemies, 2 questions.
- `app/judge.py::run_case` compares with `actual_value == expected` (loose: `1 == True`).
- Frontend `ApiService` base URL is hardcoded; GET failures silently fall back to `SeedData`.

---

# STAGE 1: Identity + gameplay fixes

### Task 1.1: Player accounts and bearer auth (backend)

**Files:**
- Modify: `backend/app/models/player.py` (add `token_hash`, `rating`, `wins`, `losses`, `hp_updated_at`, `last_active`; `username` unique)
- Create: `backend/app/auth.py`
- Modify: `backend/app/routers/player.py`, `backend/app/schemas.py`, `backend/app/seed.py` (stop inserting Player), `backend/tests/conftest.py`, `backend/tests/test_seed.py`
- Test: `backend/tests/test_auth.py`

**Interfaces:**
- Produces: `auth.hash_token(raw: str) -> str`; `auth.create_token() -> str`; FastAPI dependency `auth.get_current_player(authorization: str = Header(None), db = Depends(get_db)) -> Player` (raises 401).
- Produces: `POST /api/players {name}` -> `201 {player_id, token, player: PlayerOut}`; `GET /api/player` (auth) -> `PlayerOut`.
- Produces: test fixture `auth_client` in conftest = `client` with `Authorization` header preset for a freshly created player; `client.player_id`.

- [ ] **Step 1: Write failing tests** (`backend/tests/test_auth.py`)

```python
def test_create_player_returns_token(client):
    r = client.post("/api/players", json={"name": "Sohan"})
    assert r.status_code == 201
    body = r.json()
    assert body["token"] and body["player_id"] > 0
    assert body["player"]["display_name"] == "Sohan"

def test_duplicate_name_case_insensitive_409(client):
    client.post("/api/players", json={"name": "Sohan"})
    assert client.post("/api/players", json={"name": "sohan"}).status_code == 409

def test_name_length_validation(client):
    assert client.post("/api/players", json={"name": "a"}).status_code == 422
    assert client.post("/api/players", json={"name": "x" * 17}).status_code == 422

def test_get_player_requires_token(client):
    assert client.get("/api/player").status_code == 401
    assert client.get("/api/player", headers={"Authorization": "Bearer nope"}).status_code == 401
    assert client.get("/api/player", headers={"Authorization": "garbage"}).status_code == 401

def test_get_player_with_token(client):
    tok = client.post("/api/players", json={"name": "Ada"}).json()["token"]
    r = client.get("/api/player", headers={"Authorization": f"Bearer {tok}"})
    assert r.status_code == 200 and r.json()["display_name"] == "Ada"
```

- [ ] **Step 2:** Run `cd backend && python -m pytest tests/test_auth.py -q` -> expect FAIL (404 on `/api/players`).
- [ ] **Step 3: Implement.** `auth.py`: `create_token = secrets.token_urlsafe(32)`, `hash_token = hashlib.sha256(raw.encode()).hexdigest()`, `get_current_player` parses `Bearer <tok>`, looks up `Player.token_hash`, 401 otherwise. Player model: add columns with defaults (`rating=1000`, `wins=0`, `losses=0`, `hp_updated_at=utcnow`, `last_active`). Router: validate name via pydantic `constr(min_length=2, max_length=16)` (strip whitespace), reject case-insensitive duplicate with 409 (`func.lower(Player.username)`), set `username = name.lower()`, `display_name = name`. Remove `Player` insertion from `seed.py`.
- [ ] **Step 4:** Update `conftest.py`: add `auth_client` fixture (creates a player through the API, sets `client.headers["Authorization"]`, stores `client.player_id`). Update `test_seed.py` to stop asserting a seeded player. Run full suite; existing battle tests will fail until Task 1.2 (expected, they switch to `auth_client` there).
- [ ] **Step 5: Commit** `feat(backend): player accounts with bearer tokens`.

### Task 1.2: Per-player progress, battle ownership, unlocks, HP regen

**Files:**
- Read first: `backend/app/models/level.py`, `enemy.py`, `world.py`, `routers/levels.py`, `routers/enemies.py`, `routers/worlds.py`, `seed.py`.
- Create: `backend/app/models/progress.py` (`PlayerLevel(player_id, level_id, status, stars)` and `PlayerEnemy(player_id, enemy_id, defeated)` unique on pairs), `backend/app/progress.py` (helpers).
- Modify: `models/battle.py` (add `player_id`), `routers/battles.py`, `routers/levels.py`, `routers/enemies.py`, `routers/worlds.py` (all take `get_current_player`, return per-player status/stars/defeated/cleared_percent), `judge.py`.
- Test: `tests/test_battles.py` (switch to `auth_client`), `tests/test_progress.py`, `tests/test_judge.py`.

**Interfaces:**
- Produces: `progress.get_level_view(db, player, level) -> (status, stars)`; first level of each world is `available` for everyone, others default `locked`; `progress.unlock_next(db, player, level)` sets the next-by-`order` level in the same world to `available`.
- Produces: `progress.regen_hp(player, now) -> None` (+1 HP per 30s since `hp_updated_at`, capped at `hp_max`; call at start of start/submit and in `GET /api/player`).
- Produces: `judge.values_equal(actual, expected) -> bool` strict about bool vs int and int vs float type mismatches (`True != 1`; `1 == 1.0` allowed only if both numbers and not bool).

- [ ] **Step 1: Failing tests:** (a) player B cannot submit/run player A's battle (403); (b) winning level N makes level N+1 `available` for that player only; (c) `GET /api/levels` shows per-player status; (d) `/run` on a non-`in_progress` battle returns 400; (e) HP regen: set `hp_updated_at` 90s ago, hp 50 -> `GET /api/player` shows 53; (f) `values_equal(True, 1)` is False, `values_equal(1, 1.0)` True, `values_equal([1], [True])` False.
- [ ] **Step 2:** Run them, confirm they fail.
- [ ] **Step 3: Implement** the model/helpers; replace `Player.id == 1` in battles with the dependency player; store `battle.player_id`; 403 on mismatch; on win call `progress.unlock_next`, set `PlayerEnemy.defeated`, update `PlayerLevel` stars, update `world.cleared_percent` computation per player (completed/total); bump `wins`; on loss bump `losses`. Update `judge.run_case` to use `values_equal`.
- [ ] **Step 4:** Run the full suite -> PASS. Remove the old global `Level.status/stars` usage (keep columns as defaults only if migration is a pain; new code must not read them).
- [ ] **Step 5: Commit** `feat(backend): per-player progress, ownership, unlocks, hp regen`.

### Task 1.3: Configurable API URL, token storage, offline banner (Flutter)

**Files:**
- Modify: `frontend/codewar/pubspec.yaml` (add `shared_preferences`), `lib/services/api_service.dart`, `lib/providers/game_state.dart`, `lib/main.dart`
- Create: `lib/services/settings_store.dart` (wraps SharedPreferences: `apiUrl`, `token`, `playerName`), `lib/widgets/offline_banner.dart`
- Test: `test/services/api_service_test.dart` (inject `http.Client` fake)

**Interfaces:**
- Produces: `ApiService({http.Client? client, SettingsStore? settings})`; all requests send `Authorization: Bearer <token>`; base URL resolution order: stored `apiUrl` -> `String.fromEnvironment('API_URL')` -> platform default; `createPlayer(String name)`.
- GETs no longer fall back to `SeedData` silently: they throw `ApiException`; `GameState` exposes `bool offline` + `String? error`, and the UI shows `OfflineBanner` with Retry.

- [ ] Steps: write failing tests with a fake client (header present, URL override honored, error -> `ApiException`) -> implement -> `flutter test` -> `flutter analyze` -> commit `feat(app): configurable api url, token auth, offline state`.

### Task 1.4: Onboarding + settings screen (Flutter)

**Files:** Create `lib/screens/onboarding_screen.dart` (name entry, server URL field under "Advanced"), `lib/screens/settings_screen.dart`; modify `lib/routing/app_router.dart` (redirect to `/onboarding` when no token), `lib/screens/profile_screen.dart` (link to settings).
- [ ] Steps: widget test (empty token -> onboarding shown; submitting name calls `createPlayer`, stores token, navigates `/home`; 409 shows "name taken") -> implement -> test -> commit.

### Task 1.5: Frontend gameplay fixes

**Files:** `battle_preparation_screen.dart` (language chips from a single `Language` enum in `lib/models/language.dart`, only python/typescript), `battle_victory_screen.dart` + `battle_defeat_screen.dart` (redirect home if no result instead of fake defaults), `game_state.dart` (refetch levels/enemies/world after win; remove `_markDefeated` manual rebuild; add `copyWith` to models), `coding_battle_screen.dart` (handle `outcome == "expired"` -> defeat), remove dead `fetchQuestion`.
- [ ] Steps: tests for `Language` enum, `GameState` with fake api (win -> levels refreshed), then implement, `flutter test`, commit.

### Task 1.6: Stage close-out
- [ ] Run `cd backend && python -m pytest -q` and `cd frontend/codewar && flutter test && flutter analyze`. Tick Stage 1 in `PROGRESS.md`, commit.

---

# STAGE 2: Question engine
(Detailed bite-sized steps to be expanded at the start of the stage, after reading the then-current code. Interfaces below are fixed.)

### Task 2.1: Question model additions + cache
- Modify `models/question.py`: add `source` ("seed"|"llm"|"template"), `topic`, `content_hash` (unique), `reference_solution` (Text, nullable), `created_at`. New table `SeenQuestion(player_id, question_id)`.
- Produces: `qengine/store.py`: `save_verified(db, GeneratedQuestion) -> Question` (dedupe by hash), `pick_unseen(db, player, difficulty, topic) -> Question | None`.

### Task 2.2: Verification pipeline
- Create `backend/app/qengine/verify.py`: `build_judge_cases(entry_point, reference_solution, inputs) -> list[dict] | None` runs reference through `judge.run_case`-style execution to compute expected outputs; returns `None` if any run errors/times out, outputs are all identical, or fewer than 3 cases.
- Tests: good solution passes; crashing solution -> None; constant-output solution -> None.

### Task 2.3: Template generators
- Create `backend/app/qengine/templates.py` with >= 25 generators, each `(rng: random.Random, difficulty) -> GeneratedQuestion` containing statement, entry_point, starter code (python + typescript), reference solution, inputs. Registry `TEMPLATES: dict[topic, list[fn]]`.
- Tests: every template, with 20 seeds, passes verification and its reference solution passes its own judge cases.

### Task 2.4: LLM generator
- Create `backend/app/qengine/llm.py`: `generate_with_llm(difficulty, topic) -> GeneratedQuestion | None` using Anthropic SDK (`ANTHROPIC_API_KEY`; model id from env `CODEWAR_LLM_MODEL`, default `claude-sonnet-5-5`); strict JSON parse; any exception -> `None`. Also `hint_for(question, code) -> str`.
- Tests with a fake client: malformed JSON -> None; valid JSON -> verified question; missing key -> None without network.

### Task 2.5: Service + endpoints
- `qengine/service.py::get_question(db, player, difficulty, topic) -> Question`: try cache unseen -> LLM -> template; always succeeds.
- Endpoints: `POST /api/questions/generate`, `GET /api/topics`. Add `requirements`: `anthropic` (optional import guarded).
- Stage close-out: PROGRESS.md, commit.

# STAGE 3: Leaderboard + Practice
### Task 3.1: Leaderboard API
- `GET /api/leaderboard?scope=global|weekly|friends&limit=50` -> `{entries:[{rank, player_id, name, level, rating, xp}], me:{rank,...}}`. Weekly uses `Player.weekly_xp` + `weekly_reset_at` (new columns). Friends via `Friend(player_id, friend_id)` populated by rooms (Stage 4 writes it; Stage 3 returns self only).
- Tests: ordering by rating, tie-break by xp then id, `me` rank correct when outside top N.
### Task 3.2: Practice API
- `POST /api/practice/next {topic, difficulty, language}` -> question (no HP loss, no battle row; creates `PracticeAttempt`); `POST /api/practice/{id}/submit` -> results + mastery update; `POST /api/practice/{id}/hint`; `GET /api/practice/stats` -> per-topic mastery, streak, daily challenge (deterministic by date).
### Task 3.3: Rank screen (Flutter) -> real data, pull-to-refresh, tabs (Global/Weekly/Friends), own row pinned.
### Task 3.4: Practice screen (Flutter) -> topic grid with mastery bars, endless stream flow, hint button, daily challenge card.
- Stage close-out.

# STAGE 4: Rooms backend
### Task 4.1: Room state machine (pure Python, no I/O): `rooms/engine.py` with `Room`, states `lobby -> countdown -> running -> finished`, `join/leave/start/submit_progress/tick`, race ranking `(passed desc, finished_at asc)`, duel damage, forfeit after 30s disconnect. Fully unit-tested with a fake clock.
### Task 4.2: Elo (`rooms/rating.py::update_ratings(results) -> dict[player_id, delta]`, K=32, multi-player pairwise average) with tests.
### Task 4.3: REST: `POST /api/rooms`, `POST /api/rooms/{code}/join`, `GET /api/rooms/{code}`. Code alphabet excludes `0O1IL`.
### Task 4.4: WebSocket `/ws/rooms/{code}?token=`: events `roster`, `countdown`, `start{question}`, `progress{player,passed,total}`, `finish{standings}`; client messages `start`, `run{code,language}`, `submit{code,language}`. Judge calls run in a thread pool. Tests with Starlette TestClient `websocket_connect`.
### Task 4.5: Persist results: `RoomResult` rows, rating/XP/gold updates, `Friend` links.
- Stage close-out.

# STAGE 5: Rooms frontend
### Task 5.1: `RoomService` (web_socket_channel) + `RoomState` provider, reconnect with backoff.
### Task 5.2: Play Online hub screen (create room / enter code) + lobby screen (roster, copy/share code, host Start).
### Task 5.3: Countdown + live match screen (reuse editor, live opponent progress bars, duel HP bars), podium/results screen with rating delta.
### Task 5.4: Widget tests with a fake `RoomService`.
- Stage close-out.

# STAGE 6: UI/UX polish + tooling
### Task 6.1: Design system: `lib/ui/` with `AppCard`, `PrimaryButton`, `StatPill`, text theme in `theme.dart`; migrate all screens off inline card decorations.
### Task 6.2: Motion: page transitions, damage-hit shake/flash, animated HP/XP bars, countdown pulse, loading skeletons.
### Task 6.3: Nav: bottom bar with prominent Play Online; profile with rating, W/L, mastery.
### Task 6.4: `run_server.ps1` (venv activate, uvicorn on 0.0.0.0:8000, start `cloudflared tunnel --url http://localhost:8000` or `ngrok http 8000` if installed, print public URL); README updates (setup, tunnel, `ANTHROPIC_API_KEY`, how to join a room); replace default frontend README; add `.github/workflows` CI (pytest + flutter test).
### Task 6.5: Final: full test run, `flutter analyze`, manual smoke test of two clients in one room.
