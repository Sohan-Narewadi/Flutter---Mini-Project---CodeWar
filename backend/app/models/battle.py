from sqlalchemy import Column, Integer, String, DateTime
from app.database import Base


class Battle(Base):
    __tablename__ = "battles"

    id = Column(Integer, primary_key=True)
    player_id = Column(Integer, nullable=False, index=True)
    level_id = Column(Integer, nullable=False)
    enemy_id = Column(String, nullable=False)
    question_id = Column(String, nullable=False)
    status = Column(String, nullable=False, default="in_progress")
    started_at = Column(DateTime, nullable=False)
    time_limit_s = Column(Integer, nullable=False, default=300)
    enemy_hp_remaining = Column(Integer, nullable=False)
    enemy_hp_max = Column(Integer, nullable=False)
    best_score_percent = Column(Integer, nullable=False, default=0)
