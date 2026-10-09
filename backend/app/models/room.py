from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, Integer, String
from app.database import Base


def _utcnow():
    return datetime.now(timezone.utc).replace(tzinfo=None)


class RoomResult(Base):
    """One player's outcome in one finished room."""
    __tablename__ = "room_results"

    id = Column(Integer, primary_key=True)
    room_code = Column(String, nullable=False, index=True)
    mode = Column(String, nullable=False)
    player_id = Column(Integer, nullable=False, index=True)
    rank = Column(Integer, nullable=False)
    best_pct = Column(Integer, nullable=False, default=0)
    rating_before = Column(Integer, nullable=False, default=1000)
    rating_delta = Column(Integer, nullable=False, default=0)
    xp = Column(Integer, nullable=False, default=0)
    gold = Column(Integer, nullable=False, default=0)
    finished_at = Column(DateTime, nullable=False, default=_utcnow)
