#!/usr/bin/env bash
# Start CodeWar locally (Mac / Linux). Opens on http://127.0.0.1:8000
set -e
cd "$(dirname "$0")/backend"
PORT="${PORT:-8000}"

if [ ! -d .venv ]; then
  echo "First run: creating a Python environment and installing packages..."
  python3 -m venv .venv
  .venv/bin/python -m pip install --quiet -r requirements.txt
fi

if [ ! -f ../frontend/codewar/build/web/index.html ]; then
  echo "Note: the web app is not built yet. Run 'flutter build web' inside frontend/codewar, then start this again."
fi

echo
echo "CodeWar is starting at  http://127.0.0.1:$PORT"
for ip in $( (hostname -I 2>/dev/null || ipconfig getifaddr en0 2>/dev/null || true) | tr ' ' '\n' | grep -E '^[0-9]+\.' | head -3); do
  echo "Friends on the same Wi-Fi:  http://$ip:$PORT"
done
echo "Press Ctrl+C to stop."
echo

# Open the browser a moment after the server is up (best effort).
( sleep 3; (xdg-open "http://127.0.0.1:$PORT" || open "http://127.0.0.1:$PORT") >/dev/null 2>&1 || true ) &

exec .venv/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port "$PORT"
