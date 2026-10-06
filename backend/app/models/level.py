from sqlalchemy import Column, Integer, String
from app.database import Base


class Level(Base):
    __tablename__ = "levels"

    id = Column(Integer, primary_key=True)
    world_id = Column(String, nullable=False)
    order = Column(Integer, nullable=False)
    title = Column(String, nullable=False)
    difficulty = Column(String, nullable=False)
    status = Column(String, nullable=False, default="locked")
    stars = Column(Integer, nullable=False, default=0)
    enemy_id = Column(String, nullable=False)
    xp_reward = Column(Integer, nullable=False, default=0)
    gold_reward = Column(Integer, nullable=False, default=0)
    question_id = Column(String, nullable=False)
