from sqlalchemy import Column, Integer, String, Boolean
from app.database import Base


class Enemy(Base):
    __tablename__ = "enemies"

    id = Column(String, primary_key=True)
    name = Column(String, nullable=False)
    level = Column(Integer, nullable=False)
    difficulty = Column(String, nullable=False)
    hp_max = Column(Integer, nullable=False)
    hp_current = Column(Integer, nullable=False)
    vulnerability = Column(String, nullable=False, default="")
    tier = Column(String, nullable=False, default="minion")
    locked = Column(Boolean, nullable=False, default=False)
    unlock_hint = Column(String, nullable=False, default="")
    xp_reward = Column(Integer, nullable=False, default=0)
    gold_reward = Column(Integer, nullable=False, default=0)
