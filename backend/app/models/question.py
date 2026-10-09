from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, Integer, String, JSON, Text, UniqueConstraint
from app.database import Base


def _utcnow():
    return datetime.now(timezone.utc).replace(tzinfo=None)


class Question(Base):
    __tablename__ = "questions"

    id = Column(String, primary_key=True)
    title = Column(String, nullable=False)
    difficulty = Column(String, nullable=False)
    tags = Column(JSON, nullable=False, default=list)
    prompt = Column(String, nullable=False)
    example_input = Column(String, nullable=False, default="")
    example_output = Column(String, nullable=False, default="")
    starter_code = Column(JSON, nullable=False, default=dict)
    test_cases = Column(JSON, nullable=False, default=list)
    entry_point = Column(JSON, nullable=False, default=dict)
    judge_cases = Column(JSON, nullable=False, default=list)
    # Question engine metadata ("seed" = hand-written campaign questions)
    source = Column(String, nullable=False, default="seed")
    topic = Column(String, nullable=False, default="")
    content_hash = Column(String, nullable=True, unique=True)
    reference_solution = Column(Text, nullable=True)
    created_at = Column(DateTime, nullable=False, default=_utcnow)


class SeenQuestion(Base):
    """Which generated questions a player has already been served."""
    __tablename__ = "seen_questions"
    __table_args__ = (UniqueConstraint("player_id", "question_id"),)

    id = Column(Integer, primary_key=True)
    player_id = Column(Integer, nullable=False, index=True)
    question_id = Column(String, nullable=False)
