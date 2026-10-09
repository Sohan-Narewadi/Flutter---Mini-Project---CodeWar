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
- Final review done (fresh opus reviewer, 12 findings, all fixed with tests): hidden judge cases (only 3 examples shown, rest "(hidden)"), ghost lobby members dropped at start, preparing flag cleared on failed start, 0% submit no longer outranks a non-submitter, lapsed streak shown as 0, deterministic check + PYTHONHASHSEED for LLM references, missing node runtime handled, socket reconnect (one failure = one retry slot, judging flag reset, close code 4000 terminal), sign-out clears practice/room state, judge request timeout 60s. Backend 177 tests, Flutter 34 tests.
- Deferred (not done): `Language` enum used only in new code; model `copyWith`; LLM hint/problem quality and the tunnel path of run_server.ps1 untested here; no visual check of screens (Chrome extension unavailable).
- Branch `feature/online` is NOT merged. Next step is the owner's choice: merge to main, open a PR, or keep iterating.

## Stages 7-12: Launch polish (started 2026-10-09)
**Detailed plan: `docs/superpowers/plans/2026-10-09-codewar-launch-polish.md`** (design tokens, per-task specs, API shapes, QA harness, gotchas). Read it before working; tick tasks there AND here.
User feedback: UI "looks vibe coded / sticky"; wants launch-ready, industry-grade. Confirmed: Neon arcade style; extras = achievements, rank tiers, sound+haptics, match history. All data real.
- [x] 7 Design system (done: theme.dart tokens+aliases, lib/ui/{neon_button,app_card,segmented_tabs,stat_tile,arcade_backdrop,app_scaffold}.dart, test/ui/primitives_test.dart; 43 Flutter tests) (7.1 tokens/theme, 7.2 primitives, 7.3 backdrop/scaffold)
- [ ] 8 Shell/nav (single header on Home only, nav restyle, /online as tab)
- [ ] 9 Screens (Home, Practice, Rank podium, Profile, cleanup)
- [x] 10 Backend DONE (tiers, badges + GET /api/badges, GET /api/matches, GET /api/players/{id}/public, app/migrate.py additive column migration, wins/losses now online-only; 214 backend tests). Flutter models/services for these still TODO in 9.3/9.4
- [ ] 11 Online/battle restyle, sound + haptics, accessibility
- [ ] 12 Visual QA (Playwright at 4 widths), two-browser online test, final review
- Progress log: Stage 7 done; 8.1-8.3 done (AppShell uses AppScaffold, HomeHeader on Home only, nav restyled, /online is a tab); 9.1 Home done; 9.2 Practice screen done (+backend stats `total_solved/daily_done/daily_resets_in`, 2 tests); 11.1 Play hub done. `tools/qa_shots.py` committed (run it after `flutter build web`). NEXT: Stage 10 backend (tiers, badges, matches, public profile), then 9.3 Rank, 9.4 Profile.
- Progress log 2: 9.3 Rank (podium, live 15s refresh, public profile sheet) and 9.4 Profile (tier ring, stats, badges, match history, mastery, sign-out) DONE and screenshot-verified at 390px. Backend 215 tests, Flutter 58. Player payload now has `tier`, `best_streak`. NEXT: 11.2 room screen, 11.3 battle flow + practice_play + onboarding + settings restyle (still old look: lavender/old tokens via aliases), 11.4 sound/haptics, 11.5 a11y, then Stage 12 QA at 4 widths + two-browser online test, 9.5 cleanup (old aliases, stat_chip), final review. Dev DB has test accounts (smoke*/Tester*/QA*): delete backend/codewar.db before release.
- Progress log 3: DONE: onboarding, settings (sound/haptics toggles), `lib/services/sfx.dart` + `tools/make_sfx.py` (assets/sfx/*.wav, `audioplayers` dep added), code editor no-wrap fix (letterSpacing 0, horizontal scroll), practice_play restyle (docked action bar), coding_battle restyle, battle prep/victory/defeat REWRITTEN WITHOUT fabricated content (removed fake "Dazed -15% DEF", "Pattern Flaw", "IndexError", "1 Energy or 50 Coins", "Sector 05", "+40 XP drill"; retry now starts a real new battle; result screens hold their own copy of lastResult). Flutter 66 tests. TODO next: room_screen restyle (11.2), battle_arena restyle, delete seed_data fallbacks (GameState defaults to SeedData lists), 9.5 cleanup of aliases/stat_chip/reward_row, 11.5 a11y, Stage 12 QA at 4 widths + two-browser online test + final review.
