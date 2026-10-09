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

## What is in here

- `app/auth.py`, `routers/player.py`: name + bearer-token accounts (no passwords)
- `app/qengine/`: question engine (34 templates, optional LLM via `ANTHROPIC_API_KEY`, judge-verified, cached)
- `app/judge.py`, `app/judging.py`: runs Python/TypeScript submissions against test cases
- `app/routers/practice.py`, `leaderboard.py`: Practice mode and rankings
- `app/rooms/`, `routers/rooms.py`: online Race/Duel rooms over WebSockets (protocol in `docs/superpowers/rooms-protocol.md`)
- `scripts/smoke_rooms.py`: end-to-end check of rooms against a running server

If you upgrade from an older version, delete the old `codewar.db` once (no migrations).

## Security note

The code judge runs submitted Python/TypeScript (and LLM-written reference solutions) in a
timeout-bounded subprocess (5s per test case). There is **no OS-level sandboxing** (no
containers, no seccomp, no network denial). That is acceptable for friends over a tunnel,
but do not expose this backend to untrusted users.

## Supported judge languages

- `python` (via the interpreter running the server)
- `typescript` (via `node`, using Node's native TS type-stripping; Node 22.6+ with
  `--experimental-strip-types`, or 23.6+/24+ where it is on by default)
- C++ is not supported (the API answers HTTP 400 and the app does not offer it).
