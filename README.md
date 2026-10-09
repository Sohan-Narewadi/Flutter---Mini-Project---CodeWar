# CodeWar

A Flutter game where you fight enemies by solving coding problems. Climb a campaign world map, grind endless Practice problems, and race or duel friends online with a room code. A FastAPI backend generates problems, judges your code, runs the rooms and keeps the leaderboard.

## Project structure

| Path | Description |
|------|-------------|
| `frontend/codewar/` | Flutter app (screens, widgets, providers, services) |
| `backend/` | FastAPI + SQLAlchemy (SQLite): accounts, question engine, judge, rooms, leaderboard |
| `run_server.ps1` | One command to start the backend and a public tunnel for friends |
| `docs/superpowers/` | Design specs, implementation plan, progress tracker and the rooms protocol |

## Features

- **Campaign**: world map (Array Ruins, 8 levels, 6 enemies). Winning unlocks the next level; progress is per player.
- **Endless Practice**: pick a topic and difficulty and get a fresh problem every time, with hints, per-topic mastery, a day streak and a daily challenge (double XP, same puzzle for everyone).
- **Online rooms**: `Play` in the bottom bar. Create a Race (2-8 players) or a Duel (1v1), share the 6-character code, and compete live. Ratings (Elo), XP and friends are updated when the match ends.
- **Leaderboard**: global, weekly and friends, by total XP or online rating. All real data.
- **Accounts**: pick a name on first launch; your device keeps a secret token (no password, no email).
- **Unlimited problems**: an LLM writes new problems when `ANTHROPIC_API_KEY` is set; otherwise a built-in generator with 34 templates and randomized inputs is used. Expected outputs always come from running a reference solution through the judge, never from the model.
- In-app code editor (Python and TypeScript), judged server-side.

## Getting started

### Prerequisites

- Flutter SDK (Dart `^3.12.2`)
- Python 3.10+
- Node 22.6+ (only needed to judge TypeScript submissions)
- Optional: `cloudflared` (`winget install Cloudflare.cloudflared`) or `ngrok` for a public tunnel

### 1. Start the server (Windows)

```powershell
.\run_server.ps1            # API + public tunnel, prints a URL for your friends
.\run_server.ps1 -NoTunnel  # local / same Wi-Fi only
```

The first run creates the virtual environment and installs the requirements. To enable LLM-written problems set `ANTHROPIC_API_KEY` (and optionally `CODEWAR_LLM_MODEL`) before starting.

Manual start (any OS):

```bash
cd backend
python -m venv .venv
.venv/Scripts/python -m pip install -r requirements.txt   # .venv/bin/python on macOS/Linux
.venv/Scripts/python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

If you upgraded from an older version, delete the old `backend/codewar.db` once: the schema changed and there is no migration step.

### 2. Run the Flutter app

```bash
cd frontend/codewar
flutter pub get
flutter run                                              # emulator/desktop default URLs
flutter run --dart-define=API_URL=https://xxxx.trycloudflare.com   # point at a tunnel
```

You can also paste the server URL in the app: onboarding > Advanced, or Profile > Settings.

### 3. Play with friends

1. Host: run `.\run_server.ps1` and copy the public URL it prints.
2. Everyone: install/run the app, paste the URL in Settings, pick a name.
3. Host: Play > Create room, share the 6-character code. Friends: Play > Join with a code.
4. Host presses Start once everyone is in the lobby.

The game only works while the host's PC and the script are running.

## Tests

```bash
# Backend (about a minute)
cd backend && .venv/Scripts/python -m pytest -q

# Frontend
cd frontend/codewar && flutter analyze && flutter test

# End-to-end room check against a running server (same machine)
cd backend && .venv/Scripts/python scripts/smoke_rooms.py
```

## Notes

- Supported judge languages: `python`, `typescript`.
- The code judge runs submissions in a timeout-bounded subprocess with **no OS-level sandboxing**, and LLM-written reference solutions are executed the same way (with a basic blocklist). That is acceptable for friends over a tunnel but do not expose the server to untrusted users.
- Rooms live in memory: restarting the server ends live rooms. Finished results, ratings and XP are stored in SQLite.
- More detail: [`docs/superpowers/PROGRESS.md`](docs/superpowers/PROGRESS.md), [`docs/superpowers/rooms-protocol.md`](docs/superpowers/rooms-protocol.md).
