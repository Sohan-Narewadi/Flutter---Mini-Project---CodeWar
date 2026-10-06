from sqlalchemy import Column, Integer, String
from app.database import Base


class World(Base):
    __tablename__ = "worlds"

    id = Column(String, primary_key=True)
    name = Column(String, nullable=False)
    order = Column(Integer, nullable=False)
    description = Column(String, nullable=False, default="")
    cleared_percent = Column(Integer, nullable=False, default=0)
