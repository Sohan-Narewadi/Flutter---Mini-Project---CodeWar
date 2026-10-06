# CodeWar

A Flutter game app where you fight enemies by solving coding problems. Travel a world map, enter battles, write code in the in-app editor, and win by passing the test cases. A FastAPI backend serves the worlds, levels, enemies and questions, and judges your submissions.

## Project structure

| Path | Description |
|------|-------------|
| `frontend/codewar/` | Flutter app (screens, widgets, providers, services) |
| `backend/` | FastAPI + SQLAlchemy (SQLite) API and code judge |
| `docs/` | Design spec and implementation plan for the backend |

## Features

- World map with levels (first world: **Array Ruins**, 8 levels, 6 enemies)
- Battle flow: preparation, arena, coding battle, victory / defeat screens
- In-app code editor with starter code per language
- Practice mode, player profile and rank screens
- Backend judge that runs Python and TypeScript submissions against test cases

## Getting started

### Prerequisites

- Flutter SDK (Dart `^3.12.2`)
- Python 3.10+
- Node 22.6+ (only needed to judge TypeScript submissions)

### 1. Start the backend

```bash
cd backend
python -m venv .venv
.venv/Scripts/python -m pip install -r requirements.txt   # .venv/bin/python on macOS/Linux
.venv/Scripts/python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

The first run creates `codewar.db` and seeds it. See [`backend/README.md`](backend/README.md) for details.

### 2. Run the Flutter app

```bash
cd frontend/codewar
flutter pub get
flutter run
```

The app's default API base URL is `http://10.0.2.2:8000` (the Android emulator's alias for the host machine). For Windows desktop or web builds, the backend is reachable at `http://localhost:8000`.

## Tests

```bash
# Backend
cd backend && .venv/Scripts/python -m pytest tests/ -v

# Frontend
cd frontend/codewar && flutter test
```

## Notes

- Supported judge languages: `python`, `typescript`. C++ starter code is shown in the editor, but submissions return HTTP 400.
- The code judge runs submissions in a timeout-bounded subprocess with **no OS-level sandboxing**. It is meant for local, trusted use. Do not expose the backend to untrusted users.
