from sqlalchemy import Column, String, JSON
from app.database import Base


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
