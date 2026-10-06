import math
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.battle import Battle
from app.models.level import Level
from app.models.enemy import Enemy
from app.models.question import Question
from app.models.player import Player
from app.schemas import (
    BattleStartIn, BattleStartOut, QuestionOut,
    CodeSubmitIn, BattleRunOut, BattleSubmitOut, TestResultOut,
)
from app.judge import run_all_cases, UnsupportedLanguageError

router = APIRouter()

# Harder levels get more time to think through a solution (MVP tuning, like
# the damage/xp formulas in submit_battle below).
TIME_LIMIT_BY_DIFFICULTY = {"easy": 240, "medium": 300, "hard": 420, "boss": 600}


@router.post("/api/battles/start", response_model=BattleStartOut)
def start_battle(body: BattleStartIn, db: Session = Depends(get_db)):
    level = db.query(Level).filter(Level.id == body.level_id).first()
    if level is None:
        raise HTTPException(status_code=404, detail=f"Level {body.level_id} not found.")
    enemy = db.query(Enemy).filter(Enemy.id == level.enemy_id).first()
    question = db.query(Question).filter(Question.id == level.question_id).first()
    if enemy is None or question is None:
        raise HTTPException(status_code=404, detail="Level is missing its enemy or question.")

    started_at = datetime.now(timezone.utc)
    time_limit_s = TIME_LIMIT_BY_DIFFICULTY.get(level.difficulty, 300)
    battle = Battle(
        level_id=level.id, enemy_id=enemy.id, question_id=question.id,
        status="in_progress", started_at=started_at, time_limit_s=time_limit_s,
        enemy_hp_remaining=enemy.hp_max, enemy_hp_max=enemy.hp_max, best_score_percent=0,
    )
    db.add(battle)
    db.commit()
    db.refresh(battle)

    return BattleStartOut(
        battle_id=battle.id,
        enemy_hp_remaining=battle.enemy_hp_remaining,
        time_limit_s=battle.time_limit_s,
        started_at=started_at.isoformat(),
        question=QuestionOut.model_validate(question),
    )


def _judge(question: Question, code: str, language: str) -> tuple[list[TestResultOut], int, int]:
    try:
        entry_point = question.entry_point.get(language, "")
        results = run_all_cases(language, code, entry_point, question.judge_cases)
    except UnsupportedLanguageError as exc:
        raise HTTPException(status_code=400, detail=str(exc))

    display = question.test_cases
    out = [
        TestResultOut(
            input=display[i]["input"],
            expected=display[i]["expected_output"],
            actual=results[i]["actual"],
            passed=results[i]["passed"],
            duration_ms=results[i]["duration_ms"],
        )
        for i in range(len(results))
    ]
    passed_tests = sum(1 for r in out if r.passed)
    return out, passed_tests, len(out)


@router.post("/api/battles/{battle_id}/run", response_model=BattleRunOut)
def run_battle(battle_id: int, body: CodeSubmitIn, db: Session = Depends(get_db)):
    battle = db.query(Battle).filter(Battle.id == battle_id).first()
    if battle is None:
        raise HTTPException(status_code=404, detail=f"Battle {battle_id} not found.")
    question = db.query(Question).filter(Question.id == battle.question_id).first()

    results, passed_tests, total_tests = _judge(question, body.code, body.language)
    correctness_percent = round(100 * passed_tests / total_tests) if total_tests else 0

    return BattleRunOut(
        passed_tests=passed_tests, total_tests=total_tests, results=results,
        correctness_percent=correctness_percent,
    )


@router.post("/api/battles/{battle_id}/submit", response_model=BattleSubmitOut)
def submit_battle(battle_id: int, body: CodeSubmitIn, db: Session = Depends(get_db)):
    battle = db.query(Battle).filter(Battle.id == battle_id).first()
    if battle is None:
        raise HTTPException(status_code=404, detail=f"Battle {battle_id} not found.")
    if battle.status != "in_progress":
        raise HTTPException(status_code=400, detail=f"Battle {battle_id} is already {battle.status}.")

    now = datetime.now(timezone.utc)
    started_at = battle.started_at
    if started_at.tzinfo is None:
        started_at = started_at.replace(tzinfo=timezone.utc)
    if (now - started_at).total_seconds() > battle.time_limit_s:
        battle.status = "expired"
        db.commit()
        return BattleSubmitOut(
            passed_tests=0, total_tests=0, results=[], correctness_percent=0,
            outcome="expired", enemy_hp_remaining=battle.enemy_hp_remaining,
            enemy_hp_max=battle.enemy_hp_max, best_score_percent=battle.best_score_percent,
        )

    question = db.query(Question).filter(Question.id == battle.question_id).first()
    results, passed_tests, total_tests = _judge(question, body.code, body.language)
    correctness_percent = round(100 * passed_tests / total_tests) if total_tests else 0

    damage_dealt = round(correctness_percent / 100 * math.ceil(battle.enemy_hp_max / 3))
    battle.enemy_hp_remaining = max(0, battle.enemy_hp_remaining - damage_dealt)
    enemy_defeated = battle.enemy_hp_remaining == 0

    player = db.query(Player).filter(Player.id == 1).first()
    hp_lost = round((100 - correctness_percent) / 100 * 10)
    player.hp = max(0, player.hp - hp_lost)

    is_new_best = correctness_percent > battle.best_score_percent
    if is_new_best:
        battle.best_score_percent = correctness_percent

    xp_earned = 0
    gold_earned = 0
    outcome = "in_progress"
    if enemy_defeated:
        outcome = "won"
        battle.status = "won"
        level = db.query(Level).filter(Level.id == battle.level_id).first()
        stars = 3 if correctness_percent == 100 else (2 if correctness_percent >= 70 else 1)
        level.status = "completed"
        if stars > level.stars:
            level.stars = stars
        xp_earned = level.xp_reward
        gold_earned = level.gold_reward
        player.xp += xp_earned
        player.gold += gold_earned
        while player.xp >= player.xp_to_next:
            player.xp -= player.xp_to_next
            player.level += 1
            player.xp_to_next = round(player.xp_to_next * 1.2)
    elif player.hp == 0:
        outcome = "lost"
        battle.status = "lost"

    db.commit()

    return BattleSubmitOut(
        passed_tests=passed_tests, total_tests=total_tests, results=results,
        correctness_percent=correctness_percent, outcome=outcome,
        xp_earned=xp_earned, gold_earned=gold_earned, hp_lost=hp_lost,
        damage_dealt=damage_dealt, enemy_hp_remaining=battle.enemy_hp_remaining,
        enemy_hp_max=battle.enemy_hp_max, enemy_defeated=enemy_defeated,
        is_new_best=is_new_best, best_score_percent=battle.best_score_percent,
    )
