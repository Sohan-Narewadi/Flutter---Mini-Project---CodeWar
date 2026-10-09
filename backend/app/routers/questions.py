from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.auth import get_current_player
from app.database import get_db
from app.models.player import Player
from app.models.question import Question
from app.qengine import service
from app.qengine.templates import DIFFICULTIES, TOPIC_LABELS, TOPICS
from app.schemas import GeneratedQuestionOut, GenerateIn, QuestionOut, TopicOut

router = APIRouter()


@router.get("/api/topics", response_model=list[TopicOut])
def list_topics(player: Player = Depends(get_current_player)):
    return [TopicOut(id=t, label=TOPIC_LABELS[t]) for t in TOPICS]


@router.post("/api/questions/generate", response_model=GeneratedQuestionOut)
def generate_question(
    body: GenerateIn,
    player: Player = Depends(get_current_player),
    db: Session = Depends(get_db),
):
    if body.difficulty not in DIFFICULTIES:
        raise HTTPException(status_code=422, detail=f"difficulty must be one of {list(DIFFICULTIES)}.")
    if body.topic is not None and body.topic not in TOPICS:
        raise HTTPException(status_code=422, detail=f"topic must be one of {TOPICS}.")
    question = service.get_question(db, player.id, body.difficulty, body.topic)
    return GeneratedQuestionOut.model_validate(question)


@router.get("/api/questions/{question_id}", response_model=QuestionOut)
def get_question(question_id: str, db: Session = Depends(get_db)):
    question = db.query(Question).filter(Question.id == question_id).first()
    if question is None:
        raise HTTPException(status_code=404, detail=f"Question '{question_id}' not found.")
    return question
