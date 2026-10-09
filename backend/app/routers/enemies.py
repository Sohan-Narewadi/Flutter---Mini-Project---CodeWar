from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.auth import get_current_player
from app.database import get_db
from app.models.enemy import Enemy
from app.models.level import Level
from app.models.player import Player
from app.progress import level_states
from app.schemas import EnemyOut

router = APIRouter()


@router.get("/api/enemies", response_model=list[EnemyOut])
def list_enemies(player: Player = Depends(get_current_player), db: Session = Depends(get_db)):
    levels = db.query(Level).all()
    states = level_states(db, player, levels)
    beaten = {lv.enemy_id for lv in levels if states[lv.id][0] == "completed"}
    out = []
    for e in db.query(Enemy).all():
        item = EnemyOut.model_validate(e)
        item.defeated = e.id in beaten
        out.append(item)
    return out
