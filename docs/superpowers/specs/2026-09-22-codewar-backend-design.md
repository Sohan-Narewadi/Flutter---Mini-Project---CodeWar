# CodeWar Backend — Design Spec

Date: 2026-09-22
Status: Approved (design presented in chat; approach confirmed, no objections raised)

## Problem

The Flutter frontend (`frontend/codewar/`) is a complete client for a REST
backend that was never committed to this repo. `lib/services/api_service.dart`
and the model `fromJson` factories already encode the full contract of that
backend in comments (endpoint paths, field names, status semantics). Without
it, every read falls back to local seed data, and every battle-start attempt
throws `BattleApiException('This encounter has no backend level to battle
against.')` because seed level ids ("n1".."n8") aren't parseable as the
integer level ids `startBattle()` requires — there is no code path that lets
the app play a real battle without a live backend.

This spec defines that backend from scratch, reverse-engineered from the
frontend's existing contract.

## Goals

- Implement every endpoint `ApiService` calls, with exact request/response
  shapes the frontend already parses.
- A real, runnable code judge for Python and TypeScript submissions.
- Persist player/level/battle state across restarts.
- Seed data identical in shape and content to `seed_data.dart` so switching
  from seed-fallback to live backend is seamless.
- Reachable from Windows desktop, web (localhost), and the Android emulator
  (`10.0.2.2`, which the frontend's default `baseUrl` already assumes).

## Non-goals

- Auth / multi-user (single Player row, id=1).
- Hardened multi-tenant sandboxing (see Security note below).
- C++ execution (no compiler available in this environment); C++ starter
  code stays visible in the editor but submissions in that language return
  a "not supported" error.

## Architecture

FastAPI + SQLAlchemy + SQLite, using the naming the frontend's own comments
already assume (`backend/app/models/level.py`, `LevelOut` schema, `judge.py`):

```
backend/
  app/
    main.py          # FastAPI app, CORS, router includes
    database.py       # SQLAlchemy engine/session, SQLite file at backend/codewar.db
    models/            # ORM: player.py, world.py, level.py, enemy.py, question.py, battle.py
    schemas.py           # Pydantic I/O schemas
    routers/               # player.py, worlds.py, levels.py, enemies.py, questions.py, battles.py
    judge.py                 # sandboxed Python/TypeScript execution
    seed.py                    # populates DB with Array Ruins content on first run
  requirements.txt
  README.md
  tests/
```

Run with `uvicorn app.main:app --host 0.0.0.0 --port 8000` from `backend/`.
Binding `0.0.0.0` makes it reachable as `127.0.0.1`/`localhost` (desktop/web)
and as `10.0.2.2` (Android emulator's alias for the host loopback) without
any code change — this matches `ApiService`'s default `baseUrl`.

## Data model

- **Player** (single row, id=1): username, display_name, level, xp,
  xp_to_next, hp, hp_max, gold, streak.
- **World**: id, name, order, description, cleared_percent (int 0-100 —
  the frontend divides by 100 itself).
- **Level**: id, world_id, order, title, difficulty, status
  (`locked`/`current`/`completed`), stars, enemy_id, xp_reward, gold_reward,
  **question_id** (FK, backend-internal only — resolved server-side on
  battle start, never serialized in `LevelOut`).
- **Enemy**: id, name, level, difficulty, hp_max, hp_current, vulnerability,
  tier (`minion`/`boss`), locked, unlock_hint, xp_reward, gold_reward.
  No `question_id` in `EnemyOut` (confirmed by a frontend comment: "EnemyOut
  has no question_id field at all").
- **Question**: id, title, difficulty, tags (JSON list), prompt,
  example_input, example_output, starter_code (JSON: lang -> code),
  test_cases (JSON list of `{input, expected_output}` display strings) —
  plus backend-only judge fields: `entry_point` (JSON: lang -> function
  name, e.g. `{"python": "find_maximum", "typescript": "findMaximum"}`)
  and structured `judge_cases` (JSON list of `{args: [...], expected: <val>}`)
  used to actually invoke the code. The display test_cases and judge_cases
  describe the same cases in the same order but are separate fields — display
  strings are freeform (`"nums = [2, 7, 11, 15], target = 9"`), judge args
  are structured values the harness can pass positionally.
- **Battle**: id, level_id, enemy_id, question_id, status
  (`in_progress`/`won`/`lost`/`expired`), started_at, time_limit_s,
  enemy_hp_remaining, best_score_percent.

## API endpoints

All response field names are `snake_case`, matching every `fromJson` in
`frontend/codewar/lib/models/*.dart`.

- `GET /api/player` -> `PlayerOut`
- `GET /api/worlds` -> `list[WorldOut]`
- `GET /api/levels?world_id=<id>` -> `list[LevelOut]` (note: `LevelOut.title`,
  not `name`)
- `GET /api/enemies` -> `list[EnemyOut]`
- `GET /api/questions/{id}` -> `QuestionOut` (unused by the current frontend
  flow — `startBattle` resolves the question itself — but implemented since
  `ApiService.fetchQuestion` exists)
- `POST /api/battles/start` body `{level_id: int}` -> `BattleStartOut`:
  `{battle_id, enemy_hp_remaining, time_limit_s, started_at, question}`.
  404 if level_id doesn't exist; the frontend surfaces this as a
  `BattleApiException`.
- `POST /api/battles/{battle_id}/run` body `{code, language}` ->
  `BattleRunOut`: `{passed_tests, total_tests, results, correctness_percent}`.
  Never mutates battle/enemy/player state.
- `POST /api/battles/{battle_id}/submit` body `{code, language}` ->
  `BattleSubmitOut`: `{passed_tests, total_tests, results,
  correctness_percent, outcome, xp_earned, gold_earned, hp_lost,
  damage_dealt, enemy_hp_remaining, enemy_hp_max, enemy_defeated,
  is_new_best, best_score_percent}`. 400 if the battle is already
  finalized (not `in_progress`).
- Error body shape for all 4xx/5xx: `{"detail": "<message>"}` — the frontend
  reads `body['detail']` first and falls back to a generic message.

`TestResultOut` (used in both run/submit `results[]`):
`{input, expected, actual, passed, duration_ms}` — `input`/`expected` are the
question's display strings, `actual` is the judge's stringified return value
(or captured error text on a crash).

## Judge design

Confirmed locally: **Node 24's native TypeScript type-stripping** runs `.ts`
files directly (`node file.ts`, no `tsc`/`ts-node` needed — verified with a
throwaway file), and Python 3.14 is available. Both languages run via plain
subprocess with no extra installs.

Each test case runs as its own subprocess (isolates crashes between cases,
gives per-case `duration_ms`), 5-second wall-clock timeout per case, used
for both `/run` and `/submit`. Flow:

1. Write the submitted code to a temp file.
2. Append a small harness: `import json, sys` (or the JS equivalent), the
   submitted code, then a call `print(json.dumps(<entry_point>(*args)))`
   with `args` embedded as a JSON literal decoded at runtime (never
   string-substituted into the call expression itself, to avoid unrelated
   injection surprises from odd values).
3. Run via subprocess, capture stdout/stderr, parse the last stdout line as
   JSON, deep-compare to `expected`.
4. On timeout, non-zero exit, or non-JSON stdout: `passed=false`,
   `actual` = a short readable error string (e.g. `"Timed out after 5s"`,
   or the captured stderr's last line).
5. `language == "cpp"` (or anything else unrecognized): raise a
   `BattleApiException`-shaped 400 immediately, no subprocess spawned.

**Security note (documented in `backend/README.md`, not just this spec):**
this is a timeout-bounded subprocess sandbox appropriate for a trusted local
single-player demo. It provides no OS-level isolation (no containers,
no seccomp, no network denial) and must not be exposed to untrusted users
over a network as-is.

## Game logic (MVP formulas — tunable, called out as such in code comments)

- `correctness_percent = round(100 * passed / total)`.
- `/run`: executes the judge, returns results. Never touches enemy HP,
  player, or `Battle.status`.
- `/submit`:
  1. If `Battle.status != "in_progress"`: 400 (already finalized).
  2. If `now - started_at > time_limit_s`: set `status = "expired"`,
     return with `outcome: "expired"`, no reward/damage fields applied.
     (Server-side deadline, independent of the client's own countdown —
     the client only disables its Submit button locally.)
  3. Otherwise, run the judge, then:
     - `damage_dealt = round(correctness_percent/100 * ceil(enemy_hp_max/3))`
       (~3 fully-correct hits to clear a minion).
     - `enemy_hp_remaining = max(0, enemy_hp_remaining - damage_dealt)`;
       `enemy_defeated = enemy_hp_remaining == 0`.
     - `hp_lost = round((100-correctness_percent)/100 * 10)` (counter-attack
       scaled by how wrong the solution was); `player.hp = max(0,
       player.hp - hp_lost)`.
     - `best_score_percent = max(Battle.best_score_percent,
       correctness_percent)`; `is_new_best` if this attempt raised it.
     - outcome: `"won"` if `enemy_defeated`; else `"lost"` if
       `player.hp == 0`; else `"in_progress"`.
     - On `"won"`: `Level.status = "completed"`; stars = 3 if
       `correctness_percent == 100`, 2 if `>= 70`, else 1 (only if better
       than the level's previous stars); `player.xp += level.xp_reward`,
       `player.gold += level.gold_reward`; level-up loop:
       `while xp >= xp_to_next: xp -= xp_to_next; level += 1; xp_to_next =
       round(xp_to_next * 1.2)`.
     - On `"lost"` or `"expired"`: no rewards; enemy HP/player HP stay as
       last applied (matches "counter-attack" framing — the player can
       retry the level from Battle Preparation).

## Seeding

`app/seed.py` runs on startup if the DB is empty, inserting content that
mirrors `frontend/codewar/lib/services/seed_data.dart` 1:1 (same world,
same 8 levels, same 6 enemies, same 2 questions — `find_maximum` and
`two_sum`), plus the judge-only fields (`entry_point`, `judge_cases`) that
seed_data.dart doesn't need since it never executes code:

- `find_maximum`: entry_point `{python: find_maximum, typescript:
  findMaximum}`; judge_cases `[{args: [[3,7,2,9,4]], expected: 9},
  {args: [[-5,-1,-12]], expected: -1}, {args: [[]], expected: null}]`.
  The third case is exactly the bug the starter code calls out in its own
  comment ("Bug: Return None/null" for the empty-array path, which
  currently `return`s 0) — `null` serializes/compares cleanly through the
  JSON harness in both languages, so it's fully judged, not display-only.
- `two_sum`: entry_point `{python: two_sum, typescript: twoSum}`;
  judge_cases `[{args: [[2,7,11,15], 9], expected: [0,1]}, {args:
  [[3,2,4], 6], expected: [1,2]}, {args: [[3,3], 6], expected: [0,1]}]`.

## CORS

`CORSMiddleware` allowing all origins (`*`) — this is a local single-user
demo reachable from a Flutter web build on an arbitrary dev-server port,
so a fixed origin list would just cause friction; there's no cookie/session
auth for a wildcard origin to leak.

## Testing plan

`pytest` in `backend/tests/`:
- `test_judge.py`: Python + TS harness, pass case, fail case, timeout,
  syntax error, unsupported language.
- `test_endpoints.py`: each GET endpoint against seeded data; full
  start -> run -> submit(partial) -> submit(win) flow; resubmit-after-win
  returns 400; submit-after-deadline returns `expired`.

Manual end-to-end check after implementation: point the already-running
Flutter builds (desktop debug build, web build on :8766) at
`http://localhost:8000`, and the Android emulator build at its default
`10.0.2.2:8000`, and play through one real battle on each.
