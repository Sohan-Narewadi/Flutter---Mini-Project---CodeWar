from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.auth import get_current_player
from app.database import get_db
from app.models.player import Player
from app.models.world import World
from app.progress import cleared_percent
from app.schemas import WorldOut

router = APIRouter()


@router.get("/api/worlds", response_model=list[WorldOut])
def list_worlds(player: Player = Depends(get_current_player), db: Session = Depends(get_db)):
    worlds = db.query(World).order_by(World.order).all()
    return [
        WorldOut(
            id=w.id, name=w.name, order=w.order, description=w.description,
            cleared_percent=cleared_percent(db, player, w.id),
        )
        for w in worlds
    ]
