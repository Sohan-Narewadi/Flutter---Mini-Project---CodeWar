from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.world import World
from app.schemas import WorldOut

router = APIRouter()


@router.get("/api/worlds", response_model=list[WorldOut])
def list_worlds(db: Session = Depends(get_db)):
    return db.query(World).order_by(World.order).all()
