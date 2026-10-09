"""Picks or creates a verified question for a player.

Order: fresh LLM problem -> an unseen cached LLM problem -> fresh template.
Every returned question is judge-verified and stored, and marked as seen by
the player so they are not served the same one twice.
"""
import random
from typing import Callable

from sqlalchemy.orm import Session

from app.models.question import Question, SeenQuestion
from app.qengine.llm import generate_with_llm
from app.qengine.templates import DIFFICULTIES, TOPICS, generate_from_template
from app.qengine.types import GeneratedQuestion
from app.qengine.verify import finalize

LlmFn = Callable[[str, str | None], GeneratedQuestion | None]


def _save(db: Session, payload: dict) -> Question:
    """Stores a verified question, deduplicating on content hash."""
    existing = db.query(Question).filter(Question.content_hash == payload["content_hash"]).first()
    if existing is not None:
        return existing
    question = Question(id="g_" + payload["content_hash"][:16], **payload)
    db.add(question)
    db.commit()
    db.refresh(question)
    return question


def _unseen_cached(db: Session, player_id: int, difficulty: str, topic: str, source: str) -> Question | None:
    seen = db.query(SeenQuestion.question_id).filter(SeenQuestion.player_id == player_id)
    return (
        db.query(Question)
        .filter(
            Question.source == source, Question.topic == topic,
            Question.difficulty == difficulty.title(), Question.id.notin_(seen),
        )
        .order_by(Question.created_at.desc())
        .first()
    )


def _mark_seen(db: Session, player_id: int, question_id: str) -> None:
    exists = (
        db.query(SeenQuestion)
        .filter(SeenQuestion.player_id == player_id, SeenQuestion.question_id == question_id)
        .first()
    )
    if exists is None:
        db.add(SeenQuestion(player_id=player_id, question_id=question_id))
        db.commit()


def get_question(
    db: Session,
    player_id: int,
    difficulty: str,
    topic: str | None,
    llm: LlmFn = generate_with_llm,
    rng: random.Random | None = None,
) -> Question:
    if difficulty not in DIFFICULTIES:
        raise ValueError(f"Unknown difficulty {difficulty!r}")
    if topic is not None and topic not in TOPICS:
        raise ValueError(f"Unknown topic {topic!r}")
    rng = rng or random.Random()
    topic_id = topic or rng.choice(TOPICS)

    question: Question | None = None

    candidate = llm(difficulty, topic_id)
    if candidate is not None:
        payload = finalize(candidate)
        if payload is not None:
            question = _save(db, payload)

    if question is None:
        question = _unseen_cached(db, player_id, difficulty, topic_id, "llm")

    # Templates are cheap: retry a few times so we never hand back a repeat.
    attempts = 0
    while question is None and attempts < 5:
        attempts += 1
        payload = finalize(generate_from_template(rng, difficulty, topic_id))
        if payload is None:
            continue
        candidate_q = _save(db, payload)
        already = (
            db.query(SeenQuestion)
            .filter(SeenQuestion.player_id == player_id, SeenQuestion.question_id == candidate_q.id)
            .first()
        )
        if already is None or attempts == 5:
            question = candidate_q
    if question is None:
        raise RuntimeError("Could not generate a question.")

    _mark_seen(db, player_id, question.id)
    return question
