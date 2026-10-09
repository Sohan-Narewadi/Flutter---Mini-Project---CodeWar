# Development guide

## Set up

```bash
# server
cd backend
python -m venv .venv
.venv/Scripts/python -m pip install -r requirements.txt     # macOS/Linux: .venv/bin/python
.venv/Scripts/python -m uvicorn app.main:app --reload --port 8000

# app
cd frontend/codewar
flutter pub get
flutter run -d chrome --dart-define=API_URL=http://127.0.0.1:8000   # hot-reload web dev
```

`play.bat`, `play.sh` and `run_server.ps1` do the server part for you and serve the built web app.

## Tests

| What | Command | Notes |
|---|---|---|
| Server | `cd backend && python -m pytest -q` | about 40 seconds; uses a temporary database per test |
| App | `cd frontend/codewar && flutter analyze && flutter test` | widget tests use a mocked HTTP client and a fake WebSocket |
| Live rooms, real server | `cd backend && python scripts/smoke_rooms.py` | against a running server |

CI (`.github/workflows/ci.yml`) runs the server tests and the app analysis and tests on every push.

### Visual and end-to-end checks (`tools/`)

These drive your installed Chrome with [Playwright](https://playwright.dev/python/) (`pip install playwright`; no browser download needed). Start the server with the built web app first (`play.bat`), then:

```bash
CODEWAR_URL=http://127.0.0.1:8000 python tools/qa_shots.py --widths 360,768,1280   # screenshot every tab
CODEWAR_URL=http://127.0.0.1:8000 python tools/qa_flow.py                          # campaign, practice and room screens
CODEWAR_URL=http://127.0.0.1:8000 python tools/qa_online.py                        # two browsers play a real online match
```

Screenshots go to `docs/qa/` (ignored by git). `qa_online.py` registers two players, creates a room, joins it by code, starts the match, submits the reference solution and checks both result screens.

## The code judge

`backend/app/judge.py` runs code in a subprocess (`python -S` or `node`), appending a small harness that calls the entry point for each test case and prints one marked result line per case. Things to know:

- All cases of a submission share one process; each has its own 5 s limit (`TIMEOUT_S`).
- Results are marked with the character `\x1e` so anything the solution prints cannot be confused with a result.
- A hang is killed and reported as `Timed out after 5s` for that case only; later cases run in a fresh process.
- If the interpreter dies before running anything (syntax error), every case fails with the same message and only one process is started.
- `PYTHONHASHSEED=0` makes set and dict ordering reproducible.
- Tests: `backend/tests/test_judge.py`, `test_judge_batch.py`.

## Adding a problem template

Templates live in `backend/app/qengine/templates.py`. Each yields a `GeneratedQuestion` (title, prompt, parameter names, entry-point names, a Python reference solution, and a list of random inputs). You never write expected outputs: `verify.py` computes them by running your reference solution. Add a test in `backend/tests/test_qengine.py` if you introduce new behaviour.

## Adding a badge

Add an entry to `BADGES` in `backend/app/badges.py` with a name, description, icon name and a predicate over real data (`_stats`). Add the icon name to the map in `frontend/codewar/lib/models/profile_models.dart` and a test in `backend/tests/test_badges.py`. Badges are awarded after solves, battle wins and finished matches, and also back-filled the first time a player opens their profile.

## Design system

`frontend/codewar/lib/utils/theme.dart` holds every colour token, the text styles (Chakra Petch for headings and numbers, Inter for body, JetBrains Mono for code) and the Material theme. `lib/ui/` has the reusable pieces; use them instead of raw Material buttons and cards so the app stays consistent. Sounds are synthesized by `tools/make_sfx.py` into `frontend/codewar/assets/sfx/`.

## Running on other platforms

```bash
flutter run -d windows                                    # desktop
flutter run -d <android-emulator-id>                      # emulator reaches the PC server at http://10.0.2.2:8000 automatically
flutter run --dart-define=API_URL=http://192.168.1.23:8000   # a phone on your Wi-Fi: use your PC's address
```

Outside the web the server address can also be typed in the app (onboarding > Advanced, or Settings).

## Public link with a free tunnel

```powershell
winget install Cloudflare.cloudflared      # one time
.\run_server.ps1                           # prints a https://....trycloudflare.com address
```

Friends open that address in a browser. The tunnel exists only while the script is running. Remember the judge is not sandboxed (see README).

## Upgrading an existing database

`backend/app/migrate.py` adds any new columns on start-up and, on the upgrade that introduced online-only records, rebuilds wins and losses from the saved match results. You never need to delete `backend/codewar.db` to upgrade; delete it only to wipe all accounts.

## Using AI-written problems (optional)

Set `ANTHROPIC_API_KEY` (and optionally `CODEWAR_LLM_MODEL`) before starting the server. Generated problems are validated and their expected outputs computed by the judge, never taken from the model.
