from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, Integer, String, UniqueConstraint
from app.database import Base


def _utcnow():
    return datetime.now(timezone.utc).replace(tzinfo=None)


class PlayerBadge(Base):
    """A badge a player has really earned (one row per player and badge)."""
    __tablename__ = "player_badges"
    __table_args__ = (UniqueConstraint("player_id", "key"),)

    id = Column(Integer, primary_key=True)
    player_id = Column(Integer, nullable=False, index=True)
    key = Column(String, nullable=False)
    earned_at = Column(DateTime, nullable=False, default=_utcnow)
