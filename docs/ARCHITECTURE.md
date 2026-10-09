# Architecture

CodeWar is two programs that talk over HTTP and WebSockets:

```
┌─────────────────────────┐        HTTPS / JSON         ┌───────────────────────────────┐
│  Flutter app            │ ──────────────────────────► │  FastAPI server (backend/)    │
│  (web, Android, iOS,    │ ◄────────────────────────── │                               │
│   desktop)              │      WebSocket (rooms)      │  routers  → request handling  │
│                         │ ◄─────────────────────────► │  qengine  → problem generator │
│  screens / providers /  │                             │  judge    → runs player code  │
│  services / ui          │                             │  rooms    → live matches      │
└─────────────────────────┘                             │  SQLite   → players, results  │
                                                        └───────────────────────────────┘
```

In normal local play the server also serves the built web app, so one address (`http://127.0.0.1:8000`) is both the website and the API.

## Server (`backend/app`)

| Module | Responsibility |
|---|---|
| `main.py` | creates the app, registers routers, runs the start-up migration, serves the web build |
| `auth.py` | device-token accounts: `POST /api/players` returns a secret token; only its hash is stored; requests send `Authorization: Bearer <token>` |
| `models/` | SQLAlchemy tables (see below) |
| `schemas.py` | request and response shapes (Pydantic) |
| `routers/` | one file per area: `player`, `worlds`/`levels`/`enemies` (campaign), `battles`, `practice`, `questions`, `leaderboard`, `rooms`, `profile` (badges, matches, public profile) |
| `qengine/` | produces problems: `templates.py` (34 templates with random inputs), `llm.py` (optional AI-written problems), `verify.py` (computes expected answers by running the reference solution), `service.py` (cache and "unseen first" selection), `hints.py` |
| `judge.py`, `judging.py` | runs submitted code against test cases (details below) |
| `rooms/` | live matches: `engine.py` (pure rules: ranking, winners), `manager.py` (WebSocket sessions, timers, countdown), `rating.py` (Elo), `persist.py` (saves results) |
| `progress.py` | XP, levels, HP regeneration, per-player campaign state |
| `badges.py`, `tiers.py` | achievements derived from real data; rating to tier mapping |
| `migrate.py` | adds new columns to an existing database on start-up, so upgrades never need the database deleted |
| `webmount.py` | serves `frontend/codewar/build/web` at `/` |

### Database tables (SQLite, `backend/codewar.db`)

`players`, `worlds`, `levels`, `enemies`, `player_levels` (per-player campaign progress), `questions`, `seen_questions`, `battles`, `practice_attempts`, `practice_stats` (per-topic mastery), `friends`, `room_results` (one row per player per finished match), `player_badges`.

### How a problem is made and judged

1. A request for a problem (`/api/practice/next`, a room starting, a campaign battle) asks the question service for one the player has not seen.
2. If none is cached, a generator produces a problem: a template with random inputs, or an AI-written one when `ANTHROPIC_API_KEY` is set.
3. **Expected answers are never taken from the generator.** `verify.py` runs the reference solution through the judge on every input and stores those outputs. Problems whose reference crashes, is non-deterministic, or gives identical outputs for every input are discarded.
4. A player's submission is judged by `judge.py`: **all test cases run in one interpreter process** (starting a process is far slower than running a case). Each case has its own 5 second limit and its own error; a case that hangs or kills the interpreter is reported on its own and the rest are judged in a fresh process. Results are compared with strict JSON equality (a boolean never equals a number).
5. Only the first 3 test cases are shown to players. The rest are hidden, so a lookup table of the examples cannot pass.

The judge has **no OS-level sandbox**. See "Good to know" in the README.

### Live rooms

A room is a state machine: `lobby → countdown → running → finished`. The server owns the clock and the truth:

- Players connect to `/ws/rooms/{code}?token=...`. The server pushes a full room snapshot after every change and about once a second while running.
- `run` previews a solution privately; `submit` is scored. The first player to reach 100% wins; otherwise ranks come from best percentage at the time limit.
- When a match finishes, `persist.py` updates Elo ratings, XP, gold, wins and losses, links all participants as friends, awards badges, and writes `room_results`.
- Rooms live in memory (one server process). A disconnected player has a 30 second grace period before forfeiting.

The wire format is documented in [rooms-protocol.md](rooms-protocol.md).

## App (`frontend/codewar/lib`)

| Folder | Contents |
|---|---|
| `screens/` | one file per screen (home, practice, rank, profile, play, room, battle flow, settings, onboarding) |
| `providers/` | `GameState` (player, campaign, battles), `PracticeState`, `RoomState` (socket, reconnect with backoff). State management is `provider`. |
| `services/` | `ApiService` (HTTP), `RoomChannel` (WebSocket seam, replaceable in tests), `SettingsStore` (saved token, server URL, sound switches), `sfx.dart` (sounds and haptics) |
| `models/` | plain data classes parsed from server JSON |
| `ui/` | the design system: `NeonButton`, `AppCard`, `SegmentedTabs`, `StatTile`, `PlayerAvatar`, `ArcadeBackdrop`, `AppScaffold`, skeletons |
| `widgets/` | game-specific widgets (bottom nav, code editor, enemy card, HP bars) |
| `utils/theme.dart` | the colour palette, fonts and Material theme ("neon arcade": one cyan accent, gold for rewards, green for success, red for danger) |
| `routing/` | `go_router` routes with a redirect to onboarding when signed out |

Principles the app follows:

- **Nothing is invented.** Every number and name on screen comes from the server. Before the first successful load the app shows skeletons or an error, never placeholder stats.
- **The server is the authority** for solving, XP, ratings and results; the app only shows what it returns.
- **On the web the API address defaults to the page's own address**, so the same build works on `localhost`, on a Wi-Fi address and behind a tunnel. Other platforms use `--dart-define=API_URL=...` or the field in Settings.
