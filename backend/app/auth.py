import hashlib
import secrets

from fastapi import Depends, Header, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.player import Player


def create_token() -> str:
    return secrets.token_urlsafe(32)


def hash_token(raw: str) -> str:
    return hashlib.sha256(raw.encode()).hexdigest()


def token_from_header(authorization: str | None) -> str | None:
    if not authorization:
        return None
    parts = authorization.split(" ", 1)
    if len(parts) != 2 or parts[0].lower() != "bearer" or not parts[1].strip():
        return None
    return parts[1].strip()


def player_for_token(db: Session, raw: str | None) -> Player | None:
    if not raw:
        return None
    return db.query(Player).filter(Player.token_hash == hash_token(raw)).first()


def get_current_player(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> Player:
    player = player_for_token(db, token_from_header(authorization))
    if player is None:
        raise HTTPException(status_code=401, detail="Missing or invalid token.")
    return player
