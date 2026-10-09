from datetime import datetime, timezone

from sqlalchemy import Column, Integer, String, DateTime
from app.database import Base


def _utcnow():
    return datetime.now(timezone.utc).replace(tzinfo=None)


class Player(Base):
    __tablename__ = "players"

    id = Column(Integer, primary_key=True)
    username = Column(String, nullable=False, unique=True)
    display_name = Column(String, nullable=False)
    token_hash = Column(String, nullable=True, unique=True, index=True)
    level = Column(Integer, nullable=False, default=1)
    xp = Column(Integer, nullable=False, default=0)
    xp_to_next = Column(Integer, nullable=False, default=1000)
    hp = Column(Integer, nullable=False, default=100)
    hp_max = Column(Integer, nullable=False, default=100)
    gold = Column(Integer, nullable=False, default=0)
    streak = Column(Integer, nullable=False, default=0)
    best_streak = Column(Integer, nullable=False, default=0)
    rating = Column(Integer, nullable=False, default=1000)
    wins = Column(Integer, nullable=False, default=0)
    losses = Column(Integer, nullable=False, default=0)
    total_xp = Column(Integer, nullable=False, default=0)
    weekly_xp = Column(Integer, nullable=False, default=0)
    weekly_week = Column(String, nullable=False, default="")
    last_solve_date = Column(String, nullable=True)
    hp_updated_at = Column(DateTime, nullable=False, default=_utcnow)
    created_at = Column(DateTime, nullable=False, default=_utcnow)
