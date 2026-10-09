"""End-to-end smoke test for online rooms against a RUNNING server.

    python scripts/smoke_rooms.py [http://127.0.0.1:8000]

Creates two throwaway players, opens a race room, plays it over real
WebSockets (one player submits the reference solution read from the local
SQLite file), and checks ratings/XP came out right. Run it on the same
machine as the server so it can read codewar.db for the reference solution.
"""
import asyncio
import json
import sqlite3
import sys
import time
import urllib.request
from pathlib import Path

import websockets

BASE = (sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8000").rstrip("/")
WS = BASE.replace("http", "ws", 1)
DB = Path(__file__).resolve().parents[1] / "codewar.db"


def call(method, path, body=None, token=None):
    req = urllib.request.Request(BASE + path, method=method, data=json.dumps(body).encode() if body is not None else None)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.loads(r.read())


def reference_solution(question_id):
    con = sqlite3.connect(DB)
    try:
        return con.execute("select reference_solution from questions where id = ?", (question_id,)).fetchone()[0]
    finally:
        con.close()


async def recv_until(ws, pred, timeout=30):
    deadline = time.time() + timeout
    while time.time() < deadline:
        msg = json.loads(await asyncio.wait_for(ws.recv(), timeout=timeout))
        if pred(msg):
            return msg
    raise AssertionError("timed out waiting for message")


async def main():
    suffix = str(int(time.time()))[-6:]
    a = call("POST", "/api/players", {"name": f"smokeA{suffix}"})
    b = call("POST", "/api/players", {"name": f"smokeB{suffix}"})
    room = call("POST", "/api/rooms", {"mode": "race", "difficulty": "easy", "language": "python"}, a["token"])
    code = room["code"]
    call("POST", f"/api/rooms/{code}/join", token=b["token"])
    print("room", code)

    async with websockets.connect(f"{WS}/ws/rooms/{code}?token={a['token']}") as wa, \
               websockets.connect(f"{WS}/ws/rooms/{code}?token={b['token']}") as wb:
        await recv_until(wa, lambda m: m["type"] == "snapshot" and len(m["room"]["players"]) == 2)
        await wa.send(json.dumps({"type": "start"}))
        qa = await recv_until(wa, lambda m: m["type"] == "question")
        await recv_until(wb, lambda m: m["type"] == "question")
        question = qa["question"]
        print("question:", question["title"], "|", question["difficulty"])

        await wa.send(json.dumps({"type": "submit", "code": "def nope():\n    return 0\n", "language": "python"}))
        res = await recv_until(wa, lambda m: m["type"] == "run_result")
        print("player A wrong submit ->", res["correctness_percent"], "%")

        await wb.send(json.dumps({"type": "submit", "code": reference_solution(question["id"]), "language": "python"}))
        res = await recv_until(wb, lambda m: m["type"] == "run_result")
        print("player B reference submit ->", res["correctness_percent"], "%")
        assert res["correctness_percent"] == 100

        final = await recv_until(
            wa,
            lambda m: m["type"] == "snapshot" and m["room"]["status"] == "finished"
            and "rating_delta" in (m["room"]["standings"] or [{}])[0],
        )
        st = final["room"]["standings"]
        print("standings:", [(s["name"], s["rank"], s["rating_delta"], s["xp"]) for s in st])
        assert st[0]["name"].startswith("smokeB") and st[0]["rating_delta"] > 0 > st[1]["rating_delta"]

    me = call("GET", "/api/player", token=b["token"])
    print("winner profile:", {k: me[k] for k in ("rating", "wins", "losses", "xp", "gold")})
    board = call("GET", "/api/leaderboard?scope=friends&metric=rating", token=b["token"])
    print("friends board:", [(e["name"], e["value"]) for e in board["entries"]])
    assert len(board["entries"]) == 2
    print("SMOKE OK")


asyncio.run(main())
