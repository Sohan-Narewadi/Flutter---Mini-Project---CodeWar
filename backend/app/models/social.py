from sqlalchemy import Column, Integer, UniqueConstraint
from app.database import Base


class Friend(Base):
    """Directed friendship row; the API always writes both directions."""
    __tablename__ = "friends"
    __table_args__ = (UniqueConstraint("player_id", "friend_id"),)

    id = Column(Integer, primary_key=True)
    player_id = Column(Integer, nullable=False, index=True)
    friend_id = Column(Integer, nullable=False)
