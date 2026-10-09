from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.auth import get_current_player
from app.database import get_db
from app.models.level import Level
from app.models.player import Player
from app.progress import level_states
from app.schemas import LevelOut

router = APIRouter()


@router.get("/api/levels", response_model=list[LevelOut])
def list_levels(world_id: str, player: Player = Depends(get_current_player), db: Session = Depends(get_db)):
    levels = db.query(Level).filter(Level.world_id == world_id).order_by(Level.order).all()
    states = level_states(db, player, levels)
    return [
        LevelOut(
            id=lv.id, world_id=lv.world_id, order=lv.order, title=lv.title,
            difficulty=lv.difficulty, status=states[lv.id][0], stars=states[lv.id][1],
            enemy_id=lv.enemy_id, xp_reward=lv.xp_reward, gold_reward=lv.gold_reward,
        )
        for lv in levels
    ]
