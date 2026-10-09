from sqlalchemy import Column, Integer, String, UniqueConstraint
from app.database import Base


class PlayerLevel(Base):
    __tablename__ = "player_levels"
    __table_args__ = (UniqueConstraint("player_id", "level_id"),)

    id = Column(Integer, primary_key=True)
    player_id = Column(Integer, nullable=False, index=True)
    level_id = Column(Integer, nullable=False)
    status = Column(String, nullable=False, default="locked")
    stars = Column(Integer, nullable=False, default=0)
