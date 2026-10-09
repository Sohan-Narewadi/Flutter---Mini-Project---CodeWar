from datetime import date, datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.auth import get_current_player
from app.database import get_db
from app.judging import judge_question
from app.models.player import Player
from app.models.practice import PracticeAttempt, PracticeStat
from app.models.question import Question
from app.progress import award_xp
from app.qengine import service
from app.qengine.hints import get_hint
from app.qengine.templates import DIFFICULTIES, TOPIC_LABELS, TOPICS
from app.schemas import (
    BattleRunOut, CodeSubmitIn, GeneratedQuestionOut, HintOut, PracticeNextIn, PracticeNextOut,
    PracticeStatsOut, PracticeSubmitOut, TopicStatOut,
)

router = APIRouter()

XP_BY_DIFFICULTY = {"easy": 20, "medium": 40, "hard": 80}
MASTERY_POINTS = {"easy": 5, "medium": 10, "hard": 20}
DAILY_MULTIPLIER = 2


def _owned_attempt(db: Session, practice_id: int, player: Player) -> PracticeAttempt:
    attempt = db.query(PracticeAttempt).filter(PracticeAttempt.id == practice_id).first()
    if attempt is None:
        raise HTTPException(status_code=404, detail=f"Practice attempt {practice_id} not found.")
    if attempt.player_id != player.id:
        raise HTTPException(status_code=403, detail="That practice attempt belongs to another player.")
    return attempt


def _touch_streak(player: Player, today: date) -> None:
    """Counts consecutive days with at least one solve."""
    if player.last_solve_date == today.isoformat():
        return
    yesterday = (today - timedelta(days=1)).isoformat()
    player.streak = (player.streak + 1) if player.last_solve_date == yesterday else 1
    player.last_solve_date = today.isoformat()


@router.post("/api/practice/next", response_model=PracticeNextOut)
def practice_next(
    body: PracticeNextIn,
    player: Player = Depends(get_current_player),
    db: Session = Depends(get_db),
):
    if body.difficulty not in DIFFICULTIES:
        raise HTTPException(status_code=422, detail=f"difficulty must be one of {list(DIFFICULTIES)}.")
    if body.topic is not None and body.topic not in TOPICS:
        raise HTTPException(status_code=422, detail=f"topic must be one of {TOPICS}.")
    if body.daily:
        question = service.get_daily_question(db, player.id)
    else:
        question = service.get_question(db, player.id, body.difficulty, body.topic)
    attempt = PracticeAttempt(
        player_id=player.id, question_id=question.id, topic=question.topic,
        difficulty=question.difficulty.lower(), daily=body.daily,
    )
    db.add(attempt)
    db.commit()
    db.refresh(attempt)
    return PracticeNextOut(
        practice_id=attempt.id, daily=attempt.daily,
        question=GeneratedQuestionOut.model_validate(question),
    )


def _question_for(db: Session, attempt: PracticeAttempt) -> Question:
    return db.query(Question).filter(Question.id == attempt.question_id).first()


@router.post("/api/practice/{practice_id}/run", response_model=BattleRunOut)
def practice_run(
    practice_id: int, body: CodeSubmitIn,
    player: Player = Depends(get_current_player), db: Session = Depends(get_db),
):
    attempt = _owned_attempt(db, practice_id, player)
    results, passed, total = judge_question(_question_for(db, attempt), body.code, body.language)
    pct = round(100 * passed / total) if total else 0
    return BattleRunOut(passed_tests=passed, total_tests=total, results=results, correctness_percent=pct)


@router.post("/api/practice/{practice_id}/submit", response_model=PracticeSubmitOut)
def practice_submit(
    practice_id: int, body: CodeSubmitIn,
    player: Player = Depends(get_current_player), db: Session = Depends(get_db),
):
    attempt = _owned_attempt(db, practice_id, player)
    results, passed, total = judge_question(_question_for(db, attempt), body.code, body.language)
    pct = round(100 * passed / total) if total else 0
    attempt.best_percent = max(attempt.best_percent, pct)

    solved = pct == 100
    xp = gold = 0
    if solved:
        today = date.today()
        prior_solve = (
            db.query(PracticeAttempt)
            .filter(
                PracticeAttempt.player_id == player.id, PracticeAttempt.question_id == attempt.question_id,
                PracticeAttempt.status == "solved", PracticeAttempt.id != attempt.id,
            )
            .first()
        )
        first_time = attempt.status != "solved" and prior_solve is None
        if attempt.status != "solved":
            attempt.status = "solved"
            attempt.solved_at = datetime.now(timezone.utc).replace(tzinfo=None)
            attempt.solved_on = today.isoformat()
        _touch_streak(player, today)
        if first_time:
            xp = XP_BY_DIFFICULTY[attempt.difficulty] * (DAILY_MULTIPLIER if attempt.daily else 1)
            gold = xp // 4
            award_xp(player, xp, gold)
            stat = (
                db.query(PracticeStat)
                .filter(PracticeStat.player_id == player.id, PracticeStat.topic == attempt.topic)
                .first()
            )
            if stat is None:
                stat = PracticeStat(player_id=player.id, topic=attempt.topic, points=0, solved=0)
                db.add(stat)
            stat.points += MASTERY_POINTS[attempt.difficulty]
            stat.solved += 1
    db.commit()
    return PracticeSubmitOut(
        passed_tests=passed, total_tests=total, results=results, correctness_percent=pct,
        solved=solved, xp_earned=xp, gold_earned=gold, streak=player.streak, hints_used=attempt.hints_used,
    )


@router.post("/api/practice/{practice_id}/hint", response_model=HintOut)
def practice_hint(
    practice_id: int, body: CodeSubmitIn | None = None,
    player: Player = Depends(get_current_player), db: Session = Depends(get_db),
):
    attempt = _owned_attempt(db, practice_id, player)
    attempt.hints_used += 1
    db.commit()
    level = min(attempt.hints_used, 3)
    question = _question_for(db, attempt)
    text = get_hint(attempt.topic, question.prompt, body.code if body else "", level)
    return HintOut(level=level, hint=text)


@router.get("/api/practice/stats", response_model=PracticeStatsOut)
def practice_stats(player: Player = Depends(get_current_player), db: Session = Depends(get_db)):
    stats = {s.topic: s for s in db.query(PracticeStat).filter(PracticeStat.player_id == player.id).all()}
    solved_today = (
        db.query(PracticeAttempt)
        .filter(
            PracticeAttempt.player_id == player.id, PracticeAttempt.status == "solved",
            PracticeAttempt.solved_on == date.today().isoformat(),
        )
        .count()
    )
    # A streak that was not extended yesterday or today has lapsed.
    streak = player.streak
    if player.last_solve_date not in (date.today().isoformat(), (date.today() - timedelta(days=1)).isoformat()):
        streak = 0
    return PracticeStatsOut(
        streak=streak, solved_today=solved_today,
        topics=[
            TopicStatOut(
                id=t, label=TOPIC_LABELS[t],
                solved=stats[t].solved if t in stats else 0,
                mastery_percent=min(100, stats[t].points) if t in stats else 0,
            )
            for t in TOPICS
        ],
    )
