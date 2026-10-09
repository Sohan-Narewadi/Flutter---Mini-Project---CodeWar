# CodeWar Online: Progress Tracker

Read this first when resuming. Update and commit it at the end of every task/stage.

- Spec: `docs/superpowers/specs/2026-10-09-codewar-online-design.md`
- Plan: `docs/superpowers/plans/2026-10-09-codewar-online.md` (Stage 1 is fully detailed; Stages 2-6 have fixed interfaces and get expanded to bite-sized steps when the stage starts)
- Repo root: `D:\FLutter Mini Project\Flutter---Mini-Project---CodeWar`
- Backend: `backend/` (FastAPI). Tests: `cd backend && python -m pytest -q`
- App: `frontend/codewar/`. Tests: `flutter test`, `flutter analyze`

## Decisions (user-confirmed)
- Questions: hybrid (LLM via `ANTHROPIC_API_KEY`, template fallback), always judge-verified
- Hosting: tunnel from the user's PC (Cloudflare Tunnel / ngrok); API URL configurable in app
- Rooms: Race (2-8) and Duel (2), WebSockets
- Identity: display name + device token, no password
- User delegated all other design/UI decisions to Claude; wants work done in resumable sessions

## Status
- [x] Exploration of existing project
- [x] Design spec written and committed (`8f52070`)
- [ ] Spec reviewed/approved by user (design was approved in chat; written spec awaiting explicit review)
- [x] Implementation plan written
- [ ] Execution method chosen by user (subagent-driven vs native)

### Stage 1: Identity + fixes
- [x] 1.1 Player accounts + bearer auth (backend)
- [x] 1.2 Per-player progress, ownership, unlocks, HP regen, strict judge equality
- [x] 1.3 Configurable API URL, token storage, offline banner (app)
- [x] 1.4 Onboarding + settings screen
- [x] 1.5 Frontend gameplay fixes (language enum, no fake victory data, refresh after win)
- [x] 1.6 Close-out

### Stage 2: Question engine
- [x] 2.1 Model additions + cache
- [x] 2.2 Verification pipeline
- [x] 2.3 Template generators (25+)
- [x] 2.4 LLM generator + hints
- [x] 2.5 Service + endpoints

### Stage 3: Leaderboard + Practice
- [x] 3.1 Leaderboard API
- [x] 3.2 Practice API
- [x] 3.3 Rank screen
- [x] 3.4 Practice screen

### Stage 4: Rooms backend
- [x] 4.1 Room state machine
- [x] 4.2 Elo
- [x] 4.3 Room REST
- [x] 4.4 WebSocket
- [x] 4.5 Persistence

### Stage 5: Rooms frontend
- [x] 5.1 RoomService + RoomState
- [x] 5.2 Hub + lobby
- [x] 5.3 Match + podium
- [x] 5.4 Tests

### Stage 6: Polish + tooling
- [x] 6.1 Design system
- [x] 6.2 Motion
- [x] 6.3 Navigation/profile
- [x] 6.4 run_server.ps1, docs, CI
- [x] 6.5 Final verification

## Notes / gotchas
- Existing `Level.status/stars` and enemy-defeated state are global; Task 1.2 moves them per-player.
- Judge is not sandboxed (documented risk); fine for friends over a tunnel.
- Working tree outside this repo (`C:\Users\sohan`) is itself a git repo with lots of untracked files; always run git commands from the project folder.
- Branch: all work is on `feature/online` (not main).
- Ruling (1.2): no PlayerEnemy table; `EnemyOut.defeated` is derived from the player's completed levels. Level status stays "current"/"locked"/"completed". Seed level statuses are now ignored (per-player `player_levels` rows override; first level of a world is current by default).
- Old local `backend/codewar.db` predates the new columns: delete it once and restart the server (create_all does not migrate).
- Edit tip: multi-line python heredocs with triple quotes break in the Bash tool; write a script file and run it instead.
- Flutter SDK is at `D:\flutter\bin` (not on PATH in bash): `export PATH="/d/flutter/bin:$PATH"`. Bash tool also chokes on big multi-file heredocs: use the Write tool (after Read for existing files).
- 1.3/1.4 done: `ApiService` no longer falls back to seed data (throws `ApiException`); `GameState` has `offline/error`, `register`, `signOut`, `refreshProgress`; router is `buildRouter(GameState)` with onboarding redirect.
- Ruling (1.5): `Language` enum and model `copyWith` deferred (cosmetic; `_markDefeated` was removed in favor of `refreshProgress()`). C++ chip removed; victory/defeat now redirect home when there is no result (`NoResultRedirect`).
- Stage 1 verified: backend 47 tests pass, `flutter analyze` clean, `flutter test` 19 pass.
- Stage 2 done: `backend/app/qengine/` (types, verify, templates [34], llm, service). Endpoints: `POST /api/questions/generate {difficulty: easy|medium|hard, topic?}`, `GET /api/topics`. `anthropic` is optional (`ANTHROPIC_API_KEY`, `CODEWAR_LLM_MODEL`). Question rows gained source/topic/content_hash/reference_solution (delete old codewar.db). Judge now has `execute_case` (returns actual value) used for verification.
- Stage 3 backend done (3.1, 3.2): `GET /api/leaderboard?scope=global|weekly|friends&metric=xp|rating&limit=`, `POST /api/friends {name}`, `POST /api/practice/next {difficulty, topic?, daily?}`, `/api/practice/{id}/run|submit|hint`, `GET /api/practice/stats`. XP rules: practice XP only on the first solve of a question (easy 20/medium 40/hard 80, x2 for the daily), mastery points 5/10/20 per topic (100 = full). `progress.award_xp` is the single place XP/level/total/weekly are updated. Player gained total_xp, weekly_xp, weekly_week, last_solve_date. Remaining for Stage 3: Flutter Rank screen (3.3) and Practice screen (3.4).
- Stage 3 done: Flutter `RankScreen` (live, tabs Global/Weekly/Friends, XP vs rating, add friend), `PracticeScreen` hub (streak, daily, topic mastery) + `PracticePlayScreen` (`/practice/play`) driven by `PracticeState`. Added `Language` enum (new code only). Flutter: 23 tests pass; backend: 124 pass.
- Stage 4 done (rooms backend): `backend/app/rooms/{engine,rating,persist,manager}.py`, `backend/app/routers/rooms.py`, model `RoomResult`. Wire protocol is documented in `docs/superpowers/rooms-protocol.md` (read it before Stage 5). Rulings: `run` is private/unscored, `submit` is scored; duel is a 2-player race shown with HP bars; lobby disconnect removes the player, running disconnect has a 30s grace. Test DB is now a temp file (shared in-memory connection made threaded tests flaky). Backend: 165 tests pass (about 70s).
- Stage 5 done (rooms UI): `models/room.dart`, `services/room_channel.dart` (RoomChannel seam over web_socket_channel), `providers/room_state.dart` (reconnect with backoff, terminal close codes 4401/4403/4404), screens `play_online_screen.dart` (`/online`: create/join) and `room_screen.dart` (`/room`: lobby, countdown, race/duel match, results). Entry point is a "Play Online" banner on the Battle tab (Stage 6 should promote it in the nav). Flutter tests: 30 pass. Test tip: fake-socket events need two `pump()` calls.
- Stage 6 done: shared UI primitives (`lib/ui/`: AppCard, SkeletonBox, ShakeOnDecrease), animated HP/XP bars, fade+slide page transitions, new bottom nav (Home, Practice, centered Play, Rank, Profile; Battle Arena reachable from Home), HUD skeleton before first load, fake loadout/energy/skill-point UI removed (profile shows the real online record), `run_server.ps1` (tested with -NoTunnel; tunnel path untested because cloudflared/ngrok are not installed here), README rewrite, CI workflow, `backend/scripts/smoke_rooms.py` (passes against a real uvicorn server). NOT verified visually: the Chrome extension was not connected, so screens were only covered by widget tests and analyze.
- Remaining: whole-branch review and fixes, then merge decision (branch `feature/online` is not merged into main).
