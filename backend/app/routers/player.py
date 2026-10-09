from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.auth import create_token, get_current_player, hash_token
from app.database import get_db
from app.models.player import Player
from app.progress import effective_streak, regen_hp
from app.schemas import PlayerCreateIn, PlayerCreateOut, PlayerOut

router = APIRouter()


@router.post("/api/players", response_model=PlayerCreateOut, status_code=201)
def create_player(body: PlayerCreateIn, db: Session = Depends(get_db)):
    name = body.name.strip()
    if not 2 <= len(name) <= 16:
        raise HTTPException(status_code=422, detail="Name must be 2-16 characters.")
    if db.query(Player).filter(func.lower(Player.username) == name.lower()).first():
        raise HTTPException(status_code=409, detail="That name is taken.")
    token = create_token()
    player = Player(username=name.lower(), display_name=name, token_hash=hash_token(token))
    db.add(player)
    db.commit()
    db.refresh(player)
    return PlayerCreateOut(player_id=player.id, token=token, player=PlayerOut.model_validate(player))


@router.get("/api/player", response_model=PlayerOut)
def get_player(player: Player = Depends(get_current_player), db: Session = Depends(get_db)):
    regen_hp(player)
    db.commit()
    out = PlayerOut.model_validate(player)
    out.streak = effective_streak(player)
    return out
