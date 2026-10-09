# Roadmap and known limitations

What the project does today is described in the [README](../README.md) and [ARCHITECTURE](ARCHITECTURE.md). This page is for planning further work: what is deliberately unfinished, what to do next and roughly how much effort it is.

## Known limitations (be aware before you build on top)

| Area | Limitation | Why it matters |
|---|---|---|
| **Code judge** | Submissions run in a plain subprocess with a time limit but **no sandbox** (no container, no network block, no memory cap). | Fine for you and trusted friends. **Do not open the server to strangers** until this is replaced (see "Phase C"). |
| **Rooms** | Live rooms are held in one server process's memory. | Restarting the server ends rooms in progress. You cannot run two server instances behind a load balancer. |
| **Database** | SQLite, one file (`backend/codewar.db`). | Good for hundreds of players on one server. Not for several servers. The badge insert and the start-up migration use SQLite-specific SQL. |
| **Accounts** | A display name plus a secret token stored on the device. No email, password or recovery. | Clearing browser data or switching device loses the account. |
| **Rematch** | "New room, same settings" creates a room for the person who taps it; the opponent is not notified. | The host has to share the new code again. |
| **Match history** | Matches are grouped by room code. | Codes are only unique among rooms alive at the same time; after a server restart a code could in theory repeat and two matches would be merged. A per-match id would fix it. |
| **Leaderboard** | Updates by polling every 15 seconds while the Rank tab is open (paused in the background). | Not a push stream. |
| **Campaign** | One world ("Array Ruins", 8 levels, 6 enemies). | More content needs seed data, see below. |
| **Languages** | Python and TypeScript only. TypeScript needs Node.js 22.18+. | C++/Java/etc. need a harness and sandboxing. |
| **Platforms** | Tested in Chrome (web) and by widget tests. Android, iOS and desktop builds compile from the same code but were not run on devices. Sounds and vibration were not checked on a real device. | Do a device pass before shipping a mobile build. |
| **AI problems** | The optional AI-written problem path needs `ANTHROPIC_API_KEY` and was exercised only with a mocked client in tests. | Try it with a real key before relying on it. |
| **Tunnel** | `run_server.ps1` public tunnel (Cloudflare or ngrok) was not exercised, because neither tool was installed on the development machine. | Local and same-Wi-Fi play were tested end to end. |

## Next steps, in order

These are the stages I would take, with rough effort for one developer.

### Phase A: free public hosting for friends (3 to 5 hours)
One container (Fly.io, Render, Railway or a small VPS) that serves the web app and the API on one HTTPS address, with the SQLite file on a persistent disk. Needs: a `Dockerfile`, a start command, `flutter build web` in the image, an environment variable for the port, and a host account. WebSockets must be enabled (all of those hosts support them). Keep it invite-only until Phase C.

### Phase B: production database (1 to 2 days)
Move to managed PostgreSQL: replace the SQLite-only statements (`app/badges.py` insert-or-ignore, `app/migrate.py`), adopt Alembic migrations instead of the start-up column adder, add backups and a connection pool.

### Phase C: safe for strangers (1 to 2 days)
Run the judge in isolated containers (or a service such as Judge0): no network, CPU and memory limits, a read-only file system, a non-root user. Add rate limiting on account creation and submissions, restrict CORS to your own origin, and add basic abuse reporting.

### Phase D: more than one server (2 to 3 days)
Share room state and broadcasts between instances (for example Redis pub/sub), or pin each room to one instance. Only needed once a single server is not enough.

## Product ideas, by theme

- **Social:** invite a friend straight into a room, notify the opponent of a rematch, friend requests and a friends list screen, spectator mode, in-room chat or emotes.
- **Competitive:** seasonal ladders with resets and rewards, tournaments, a ranked queue (match with someone near your rating without a code), anti-cheat (paste detection, plagiarism similarity).
- **Progression:** more worlds and bosses, cosmetic avatar frames unlocked by badges and tiers, streak freezes, weekly challenges.
- **Learning:** show the reference solution after a solve, per-topic recommendations from weak areas, a "review mistakes" mode.
- **Platform:** Android and iOS store packaging (icons, splash screen, signing), push notifications, localization, an accessibility audit, analytics and crash reporting.
- **Accounts:** optional email or social sign-in with account recovery, keeping the name-only play as the default.

## Where to change what

| I want to... | Change this | Also |
|---|---|---|
| Add a problem type | `backend/app/qengine/templates.py` | tests in `backend/tests/test_qengine.py`. You only write the prompt, a reference solution and random inputs; expected outputs are computed. |
| Add a badge | `backend/app/badges.py` (`BADGES`) | icon name in `frontend/codewar/lib/models/profile_models.dart`, test in `backend/tests/test_badges.py` |
| Change tier thresholds | `backend/app/tiers.py` **and** `frontend/codewar/lib/models/tier.dart` | each side has a test with the same boundary values (`backend/tests/test_tiers.py`, `frontend/codewar/test/models/models_test.dart`); update both |
| Change the rating formula | `backend/app/rooms/rating.py` (`K_FACTOR`) | `backend/tests/test_rating.py` |
| Change room rules (players, time limits, countdown, forfeit grace) | `backend/app/rooms/engine.py` constants and logic | `docs/rooms-protocol.md`, `test_room_engine.py` |
| Change XP or gold rewards | practice: `backend/app/routers/practice.py`; rooms: `backend/app/rooms/persist.py`; campaign: level rewards in `backend/app/seed.py` | the matching tests |
| Add a campaign world, level or enemy | `backend/app/seed.py` (runs only on an empty database, so also add rows to an existing database or start fresh) | |
| Add a language | judge harness and `SUPPORTED_LANGUAGES` in `backend/app/judge.py`, starter code and entry points in `qengine/verify.py` and `templates.py`, `Language` enum in `frontend/codewar/lib/models/language.dart` | add judge tests; consider sandboxing first |
| Add an API endpoint | a router in `backend/app/routers/`, register it in `app/main.py`, request/response shapes in `app/schemas.py` | `docs/API.md`, a test, and a method in `frontend/codewar/lib/services/api_service.dart` |
| Add a screen | `frontend/codewar/lib/screens/`, route in `lib/routing/app_router.dart` | for a main tab also `lib/widgets/bottom_nav_bar.dart` |
| Change colours, fonts or the look | `frontend/codewar/lib/utils/theme.dart` and the components in `lib/ui/` | run `tools/qa_shots.py` to check every screen |
| Change sounds | `tools/make_sfx.py`, then run it | writes `frontend/codewar/assets/sfx/` |
| Change the database schema | edit the model in `backend/app/models/`; new nullable or defaulted columns are added automatically by `app/migrate.py` | anything else (renames, drops, new constraints) needs a manual migration, or Alembic in Phase B |

## Working conventions

- **Tests first.** Add a failing test, then the change. Server: `cd backend && python -m pytest -q`. App: `flutter analyze && flutter test`.
- **Never show invented data.** If the server hasn't provided it, show a loading state, an error or a dash, not a default number.
- **The server decides.** Scores, XP, ratings and results are computed and stored on the server; the app only displays them.
- **Check the UI at several widths** with `tools/qa_shots.py`, and check large text: there is a layout test that opens every tab at 360px wide with 130% text and fails on any overflow.
- **Keep the docs in step.** Update `docs/API.md` and `docs/rooms-protocol.md` with endpoint or message changes, and add a line to `CHANGELOG.md`.
