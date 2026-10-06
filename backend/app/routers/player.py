from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.player import Player
from app.schemas import PlayerOut

router = APIRouter()


@router.get("/api/player", response_model=PlayerOut)
def get_player(db: Session = Depends(get_db)):
    return db.query(Player).filter(Player.id == 1).first()
