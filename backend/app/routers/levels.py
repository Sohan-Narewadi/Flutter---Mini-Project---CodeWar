from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.level import Level
from app.schemas import LevelOut

router = APIRouter()


@router.get("/api/levels", response_model=list[LevelOut])
def list_levels(world_id: str, db: Session = Depends(get_db)):
    return db.query(Level).filter(Level.world_id == world_id).order_by(Level.order).all()
