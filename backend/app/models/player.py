from sqlalchemy import Column, Integer, String
from app.database import Base


class Player(Base):
    __tablename__ = "players"

    id = Column(Integer, primary_key=True)
    username = Column(String, nullable=False)
    display_name = Column(String, nullable=False)
    level = Column(Integer, nullable=False, default=1)
    xp = Column(Integer, nullable=False, default=0)
    xp_to_next = Column(Integer, nullable=False, default=1000)
    hp = Column(Integer, nullable=False, default=100)
    hp_max = Column(Integer, nullable=False, default=100)
    gold = Column(Integer, nullable=False, default=0)
    streak = Column(Integer, nullable=False, default=0)
