from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session, sessionmaker

from app.auth import get_current_player, player_for_token
from app.database import get_db
from app.judge import SUPPORTED_LANGUAGES
from app.models.player import Player
from app.rooms.engine import MAX_PLAYERS, TIME_LIMIT_S, RoomError
from app.rooms.manager import manager
from app.schemas import RoomCreateIn

router = APIRouter()

# WebSocket close codes (4000+ are application-defined)
WS_UNAUTHORIZED = 4401
WS_NOT_FOUND = 4404
WS_REJECTED = 4403


def _http(exc: RoomError) -> HTTPException:
    status = 409 if exc.code in ("full", "started") else 400
    return HTTPException(status_code=status, detail=exc.message)


@router.post("/api/rooms", status_code=201)
def create_room(
    body: RoomCreateIn,
    player: Player = Depends(get_current_player),
    db: Session = Depends(get_db),
):
    if body.mode not in MAX_PLAYERS:
        raise HTTPException(status_code=422, detail=f"mode must be one of {list(MAX_PLAYERS)}.")
    if body.difficulty not in TIME_LIMIT_S:
        raise HTTPException(status_code=422, detail=f"difficulty must be one of {list(TIME_LIMIT_S)}.")
    if body.language not in SUPPORTED_LANGUAGES:
        raise HTTPException(status_code=422, detail=f"language must be one of {sorted(SUPPORTED_LANGUAGES)}.")
    rt = manager.create(player, body.mode, body.difficulty, body.language, sessionmaker(bind=db.get_bind()))
    return manager.snapshot(rt)


@router.get("/api/rooms/{code}")
def get_room(code: str, player: Player = Depends(get_current_player)):
    rt = manager.get(code)
    if rt is None:
        raise HTTPException(status_code=404, detail="No room with that code.")
    return manager.snapshot(rt)


@router.post("/api/rooms/{code}/join")
def join_room(code: str, player: Player = Depends(get_current_player)):
    rt = manager.get(code)
    if rt is None:
        raise HTTPException(status_code=404, detail="No room with that code.")
    try:
        manager.rest_join(rt, player)
    except RoomError as exc:
        raise _http(exc)
    return manager.snapshot(rt)


@router.websocket("/ws/rooms/{code}")
async def room_socket(ws: WebSocket, code: str, token: str = "", db: Session = Depends(get_db)):
    await ws.accept()
    player = player_for_token(db, token)
    factory = sessionmaker(bind=db.get_bind())
    db.close()  # release the connection now; the socket can live for minutes
    if player is None:
        await ws.close(code=WS_UNAUTHORIZED)
        return
    rt = manager.get(code)
    if rt is None:
        await ws.close(code=WS_NOT_FOUND)
        return
    rt.session_factory = factory
    pid = player.id
    try:
        await manager.connect(rt, player, ws)
    except RoomError as exc:
        await ws.send_json({"type": "error", "code": exc.code, "message": exc.message})
        await ws.close(code=WS_REJECTED)
        return

    try:
        while True:
            msg = await ws.receive_json()
            kind = msg.get("type") if isinstance(msg, dict) else None
            try:
                if kind == "start":
                    await manager.start(rt, pid)
                elif kind in ("run", "submit"):
                    code_text = msg.get("code")
                    if not isinstance(code_text, str):
                        raise RoomError("bad_message", "Missing code.")
                    language = msg.get("language") or rt.room.language
                    await manager.judge(rt, ws, pid, kind, code_text, language)
                elif kind == "leave":
                    await manager.leave(rt, pid, ws)
                    await ws.close(code=1000)
                    return
                elif kind == "ping":
                    await ws.send_json({"type": "pong"})
                else:
                    raise RoomError("bad_message", "Unknown message type.")
            except RoomError as exc:
                await ws.send_json({"type": "error", "code": exc.code, "message": exc.message})
    except WebSocketDisconnect:
        pass
    finally:
        await manager.disconnect(rt, pid, ws)
