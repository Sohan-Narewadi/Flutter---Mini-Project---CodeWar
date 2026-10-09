# CodeWar Online: Design Spec

Date: 2026-10-09. Extends `2026-09-22-codewar-backend-design.md`.

## Goal
Make CodeWar feel fresh and social: unlimited new problems, online rooms (Race and Duel) joined by a room code, a real leaderboard, a much better Practice mode, and a polished mainstream UI. Fix known gameplay gaps along the way.

## Confirmed decisions
- Question source: **hybrid**. LLM-generated problems, with a template generator as the free fallback.
- Hosting: **tunnel from the user's PC** (Cloudflare Tunnel or ngrok). API URL is configurable, so moving to cloud hosting later is a config change.
- Room modes: **Race** (2-8 players) and **Duel** (2 players, HP framing) sharing one engine.
- Identity: **display name + device token** (no password/email). Upgradeable to real auth later.
- Realtime: **WebSockets** (FastAPI native).

## Non-goals
OS-level judge sandboxing (documented risk; basic time/output limits only), co-op boss mode, email/password accounts, cloud deployment.

## 1. Identity and data
- `POST /api/players {name}` returns `{player_id, token}`. App stores token, sends `Authorization: Bearer <token>`.
- Remove the hardcoded `Player(id=1)`. All battles, rewards, rooms are tied to the caller.
- Player gains: `token_hash`, `rating` (default 1000), `wins`, `losses`, `streak`, `last_active`, `hp_updated_at`.
- Names are unique (case-insensitive), 2-16 chars.
- API base URL: `--dart-define=API_URL`, overridable in an in-app settings field, persisted locally.

## 2. Question engine
- `POST /api/questions/generate?difficulty=&topic=` returns a verified question.
- **LLM path:** prompt for strict JSON (statement, entry_point, starter_code per language, reference_solution in Python, test inputs). Backend runs the reference solution through the judge to compute expected outputs; LLM-supplied expected values are never trusted. Discard on any failure (invalid JSON, timeout, non-deterministic, empty outputs). Key from `ANTHROPIC_API_KEY`; absent key means templates only.
- **Template path:** 25-30 parameterized generators (arrays, strings, math, hash maps, two pointers, simple DP) with randomized inputs and a built-in solver.
- Verified questions are cached in the DB with `source` (llm/template), `topic`, `difficulty`, and a content hash for dedupe. Serving prefers questions the player has not seen.
- Battles, Practice, Rooms all draw from this engine.

## 3. Rooms
- `POST /api/rooms {mode, difficulty, language}` returns a 6-char code (no ambiguous characters). `POST /api/rooms/{code}/join`. WebSocket `/ws/rooms/{code}?token=`.
- Lifecycle: lobby (live roster, host starts) -> 3-2-1 countdown -> same problem to all -> Run/Submit broadcast `{player, passed, total}` -> end on 100% solve, timeout, or all done -> podium.
- Race ranking: tests passed desc, then time asc. Duel: each submit damages the opponent proportional to tests passed.
- Server owns clock and scoring; clients cannot claim results. Disconnect grace 30s, then forfeit.
- Results update Elo-style rating, XP, gold, win/loss.
- Limits: max 8 players, room expires when empty or after 2h idle.

## 4. Leaderboard
- `GET /api/leaderboard?scope=global|weekly|friends`, built from real rating/XP, includes caller's actual rank. Friends = players met in a shared room. Tap row for profile card.
- Remove all fabricated rows from the Rank screen.

## 5. Practice, UI, UX
- **Practice:** choose topic/difficulty/language, endless generated stream, no HP loss, hint button (LLM, canned hints on fallback), streak, daily challenge, per-topic mastery bars.
- **UI refresh:** shared design system (card, button, chip widgets; real text theme; animated transitions, hit effects, countdown), onboarding screen, bottom nav with prominent "Play Online", loading skeletons, offline/error banners.
- **Fixes:** unlock next level and refresh progress after a win; HP regenerates over time; hide C++; remove fake victory/defeat defaults; block `/run` after battle end; strict type comparison in judge; keep seed-vs-backend id mismatch from failing silently.
- **Dev tooling:** `run_server.ps1` starts backend + tunnel and prints the public URL.

## 6. Testing
Backend: pytest for auth, generator (both paths, verification, dedupe), room state machine and scoring (incl. forfeit, ties), leaderboard, Elo. WebSocket tests via Starlette TestClient. Frontend: unit tests for GameState/ApiService with fakes, model tests, key widget tests.

## 7. Delivery in sessions
Work is split into stages, each independently shippable and committed, so a session ending never leaves things half-done. Progress was tracked stage by stage.

1. **Stage 1: Identity + fixes.** Players/tokens, configurable API URL, onboarding, gameplay fixes.
2. **Stage 2: Question engine.** Templates, LLM path, caching, verification.
3. **Stage 3: Leaderboard + Practice.** Real leaderboard, new Practice mode.
4. **Stage 4: Rooms backend.** Room state machine, WebSockets, Elo.
5. **Stage 5: Rooms frontend.** Lobby, countdown, live race/duel screens, podium.
6. **Stage 6: UI/UX polish + tooling.** Design system pass, animations, `run_server.ps1`, docs.
