from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.enemy import Enemy
from app.schemas import EnemyOut

router = APIRouter()


@router.get("/api/enemies", response_model=list[EnemyOut])
def list_enemies(db: Session = Depends(get_db)):
    return db.query(Enemy).all()
