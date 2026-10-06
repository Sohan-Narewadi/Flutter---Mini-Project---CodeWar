from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.question import Question
from app.schemas import QuestionOut

router = APIRouter()


@router.get("/api/questions/{question_id}", response_model=QuestionOut)
def get_question(question_id: str, db: Session = Depends(get_db)):
    question = db.query(Question).filter(Question.id == question_id).first()
    if question is None:
        raise HTTPException(status_code=404, detail=f"Question '{question_id}' not found.")
    return question
