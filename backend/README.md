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
