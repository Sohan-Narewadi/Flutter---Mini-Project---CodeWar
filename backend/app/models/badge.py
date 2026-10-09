from sqlalchemy import Column, DateTime, Integer, String, UniqueConstraint
from app.database import Base


class PlayerBadge(Base):
    """A badge a player has really earned (one row per player and badge)."""
    __tablename__ = "player_badges"
    __table_args__ = (UniqueConstraint("player_id", "key"),)

    id = Column(Integer, primary_key=True)
    player_id = Column(Integer, nullable=False, index=True)
    key = Column(String, nullable=False)
    # NULL for badges back-filled after the fact: they were earned earlier but the real date is unknown.
    earned_at = Column(DateTime, nullable=True)
