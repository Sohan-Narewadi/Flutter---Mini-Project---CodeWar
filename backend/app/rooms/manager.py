"""Runtime for live rooms: registry, sockets, timers, judging, persistence.

Rooms live in memory (they are short-lived). Only finished results are
written to the database. All engine mutations happen on the event loop;
judging and DB work run in worker threads.
"""
import asyncio
import secrets
import time
from types import SimpleNamespace

from fastapi import HTTPException, WebSocket
from sqlalchemy.orm import sessionmaker

from app.judging import judge_question
from app.models.player import Player
from app.qengine import service
from app.rooms import engine
from app.rooms.engine import Room, RoomError
from app.rooms.persist import persist_results
from app.schemas import GeneratedQuestionOut

CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"  # no 0/O/1/I/L
CODE_LENGTH = 6
COUNTDOWN_S = engine.COUNTDOWN_S
GRACE_S = engine.DISCONNECT_GRACE_S
TICK_S = 0.25
SNAPSHOT_EVERY_S = 1.0
IDLE_LOBBY_S = 2 * 3600
KEEP_FINISHED_S = 600
MAX_CODE_CHARS = 20000


def _now() -> float:
    return time.monotonic()


class Runtime:
    def __init__(self, room: Room, session_factory: sessionmaker):
        self.room = room
        self.session_factory = session_factory
        self.sockets: dict[int, WebSocket] = {}
        self.question = None          # SimpleNamespace used by the judge
        self.question_payload = None  # public JSON sent to clients
        self.preparing = False
        self.judging: set[int] = set()
        self.rewards: dict[int, dict] | None = None
        self.persisted = False
        self.loop_task: asyncio.Task | None = None


class RoomManager:
    def __init__(self):
        self.rooms: dict[str, Runtime] = {}

    # --- registry -------------------------------------------------------

    def reset(self) -> None:
        for rt in list(self.rooms.values()):
            task = rt.loop_task
            if task is not None and not task.done():
                try:
                    task.get_loop().call_soon_threadsafe(task.cancel)
                except RuntimeError:
                    pass
        self.rooms.clear()

    def get(self, code: str) -> Runtime | None:
        return self.rooms.get(code.strip().upper())

    def _sweep(self) -> None:
        now = _now()
        for code, rt in list(self.rooms.items()):
            room = rt.room
            idle_lobby = room.status == "lobby" and now - room.created_at > IDLE_LOBBY_S
            done = room.status == "finished" and room.finished_at is not None and now - room.finished_at > KEEP_FINISHED_S
            if room.closed or idle_lobby or done:
                self.rooms.pop(code, None)

    def _new_code(self) -> str:
        while True:
            code = "".join(secrets.choice(CODE_ALPHABET) for _ in range(CODE_LENGTH))
            if code not in self.rooms:
                return code

    def create(self, host: Player, mode: str, difficulty: str, language: str,
               session_factory: sessionmaker) -> Runtime:
        self._sweep()
        now = _now()
        room = Room(self._new_code(), mode, difficulty, language, host.id, host.display_name, now,
                    countdown_s=COUNTDOWN_S, grace_s=GRACE_S)
        room.disconnect(host.id, now)  # becomes "connected" when their socket opens
        rt = Runtime(room, session_factory)
        self.rooms[room.code] = rt
        return rt

    def rest_join(self, rt: Runtime, player: Player) -> None:
        now = _now()
        is_new = rt.room.join(player.id, player.display_name, now)
        if is_new:
            rt.room.disconnect(player.id, now)

    def snapshot(self, rt: Runtime) -> dict:
        snap = rt.room.snapshot(_now())
        snap["preparing"] = rt.preparing
        if rt.rewards and snap["standings"]:
            for s in snap["standings"]:
                s.update(rt.rewards.get(s["player_id"], {}))
        return snap

    # --- sockets --------------------------------------------------------

    async def _send(self, ws: WebSocket, message: dict) -> bool:
        try:
            await ws.send_json(message)
            return True
        except Exception:
            return False

    async def broadcast(self, rt: Runtime, message: dict) -> None:
        for pid, ws in list(rt.sockets.items()):
            if not await self._send(ws, message):
                rt.sockets.pop(pid, None)

    async def broadcast_snapshot(self, rt: Runtime) -> None:
        await self.broadcast(rt, {"type": "snapshot", "room": self.snapshot(rt)})

    async def connect(self, rt: Runtime, player: Player, ws: WebSocket) -> None:
        old = rt.sockets.get(player.id)
        rt.sockets[player.id] = ws
        if old is not None and old is not ws:
            try:
                await old.close(code=4000)
            except Exception:
                pass
        now = _now()
        try:
            rt.room.join(player.id, player.display_name, now)
        except RoomError:
            if rt.sockets.get(player.id) is ws:
                rt.sockets.pop(player.id, None)
            raise
        rt.room.reconnect(player.id)
        await self.broadcast_snapshot(rt)
        if rt.room.status in ("running", "finished") and rt.question_payload is not None:
            await self._send(ws, {"type": "question", "question": rt.question_payload})

    async def disconnect(self, rt: Runtime, player_id: int, ws: WebSocket) -> None:
        if rt.sockets.get(player_id) is not ws:
            return  # replaced by a newer connection
        rt.sockets.pop(player_id, None)
        room = rt.room
        now = _now()
        if room.status == "lobby":
            room.leave(player_id, now)
        else:
            room.disconnect(player_id, now)
        if room.closed:
            self.rooms.pop(room.code, None)
            return
        await self.broadcast_snapshot(rt)

    # --- actions --------------------------------------------------------

    def _make_question(self, rt: Runtime) -> None:
        db = rt.session_factory()
        try:
            room = rt.room
            q = service.get_question(db, room.host_id, room.difficulty, None)
            for pid in list(room.members):
                service.mark_seen(db, pid, q.id)
            rt.question = SimpleNamespace(
                id=q.id, entry_point=q.entry_point, judge_cases=q.judge_cases, test_cases=q.test_cases,
            )
            rt.question_payload = GeneratedQuestionOut.model_validate(q).model_dump()
        finally:
            db.close()

    async def start(self, rt: Runtime, player_id: int) -> None:
        room = rt.room
        room.check_can_start(player_id)
        if rt.preparing:
            raise RoomError("preparing", "The problem is already being prepared.")
        rt.preparing = True
        await self.broadcast_snapshot(rt)
        try:
            await asyncio.to_thread(self._make_question, rt)
            room.start(player_id, _now())  # re-validates (roster may have changed)
        except Exception as exc:
            rt.preparing = False
            await self.broadcast_snapshot(rt)  # un-stick every client's Start button
            if isinstance(exc, RoomError):
                raise
            raise RoomError("no_question", "Could not prepare a problem. Please try again.")
        rt.preparing = False
        rt.loop_task = asyncio.create_task(self._loop(rt))
        await self.broadcast_snapshot(rt)

    async def _loop(self, rt: Runtime) -> None:
        room = rt.room
        last_snapshot = 0.0
        try:
            while room.status in ("countdown", "running"):
                events = room.tick(_now())
                if "running" in events:
                    await self.broadcast(rt, {"type": "question", "question": rt.question_payload})
                    await self.broadcast_snapshot(rt)
                    last_snapshot = _now()
                if "finished" in events:
                    await self._on_finished(rt)
                    return
                if _now() - last_snapshot >= SNAPSHOT_EVERY_S:
                    await self.broadcast_snapshot(rt)
                    last_snapshot = _now()
                await asyncio.sleep(TICK_S)
        except asyncio.CancelledError:
            raise

    async def _on_finished(self, rt: Runtime) -> None:
        if rt.persisted:
            return
        rt.persisted = True
        room = rt.room
        standings = room.standings()

        def work():
            db = rt.session_factory()
            try:
                return persist_results(db, room.code, room.mode, room.difficulty, room.finish_reason, standings)
            finally:
                db.close()

        try:
            rt.rewards = await asyncio.to_thread(work)
        except Exception:
            rt.rewards = {}
        await self.broadcast_snapshot(rt)

    async def judge(self, rt: Runtime, ws: WebSocket, player_id: int, kind: str, code: str, language: str) -> None:
        room = rt.room
        if room.status != "running" or rt.question is None:
            raise RoomError("not_running", "The match is not running.")
        member = room.members.get(player_id)
        if member is None:
            raise RoomError("not_member", "You are not in this room.")
        if member.forfeited:
            raise RoomError("forfeited", "You left this match.")
        if player_id in rt.judging:
            raise RoomError("busy", "Still judging your last run.")
        if len(code) > MAX_CODE_CHARS:
            raise RoomError("too_long", "That code is too long.")
        rt.judging.add(player_id)
        try:
            results, passed, total = await asyncio.to_thread(judge_question, rt.question, code, language)
        except HTTPException as exc:
            raise RoomError("bad_language", str(exc.detail))
        finally:
            rt.judging.discard(player_id)

        pct = round(100 * passed / total) if total else 0
        await self._send(ws, {
            "type": "run_result", "kind": kind, "passed_tests": passed, "total_tests": total,
            "correctness_percent": pct, "results": [r.model_dump() for r in results],
        })
        if kind != "submit":
            return
        try:
            room.submit(player_id, passed, total, _now())
        except RoomError:
            if room.status == "finished":
                await self._on_finished(rt)
            raise
        if room.status == "finished":
            await self._on_finished(rt)
        else:
            await self.broadcast_snapshot(rt)

    async def leave(self, rt: Runtime, player_id: int, ws: WebSocket) -> None:
        if rt.sockets.get(player_id) is ws:
            rt.sockets.pop(player_id, None)
        rt.room.leave(player_id, _now())
        if rt.room.closed:
            self.rooms.pop(rt.room.code, None)
            return
        await self.broadcast_snapshot(rt)


manager = RoomManager()
