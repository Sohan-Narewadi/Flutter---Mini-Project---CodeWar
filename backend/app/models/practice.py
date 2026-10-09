from datetime import datetime, timezone

from sqlalchemy import Boolean, Column, DateTime, Integer, String, UniqueConstraint
from app.database import Base


def _utcnow():
    return datetime.now(timezone.utc).replace(tzinfo=None)


class PracticeAttempt(Base):
    __tablename__ = "practice_attempts"

    id = Column(Integer, primary_key=True)
    player_id = Column(Integer, nullable=False, index=True)
    question_id = Column(String, nullable=False)
    topic = Column(String, nullable=False, default="")
    difficulty = Column(String, nullable=False, default="easy")
    daily = Column(Boolean, nullable=False, default=False)
    status = Column(String, nullable=False, default="in_progress")  # in_progress | solved
    best_percent = Column(Integer, nullable=False, default=0)
    hints_used = Column(Integer, nullable=False, default=0)
    started_at = Column(DateTime, nullable=False, default=_utcnow)
    solved_at = Column(DateTime, nullable=True)
    solved_on = Column(String, nullable=True)  # local date, YYYY-MM-DD


class PracticeStat(Base):
    """Per-player, per-topic mastery."""
    __tablename__ = "practice_stats"
    __table_args__ = (UniqueConstraint("player_id", "topic"),)

    id = Column(Integer, primary_key=True)
    player_id = Column(Integer, nullable=False, index=True)
    topic = Column(String, nullable=False)
    points = Column(Integer, nullable=False, default=0)
    solved = Column(Integer, nullable=False, default=0)
