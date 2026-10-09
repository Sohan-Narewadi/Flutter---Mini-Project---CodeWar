import math
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.auth import get_current_player
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
from app.badges import award_badges
from app.progress import award_xp, complete_level, level_states, regen_hp
from app.judging import judge_question

router = APIRouter()

# Harder levels get more time to think through a solution (MVP tuning, like
# the damage/xp formulas in submit_battle below).
TIME_LIMIT_BY_DIFFICULTY = {"easy": 240, "medium": 300, "hard": 420, "boss": 600}


@router.post("/api/battles/start", response_model=BattleStartOut)
def start_battle(body: BattleStartIn, player: Player = Depends(get_current_player), db: Session = Depends(get_db)):
    level = db.query(Level).filter(Level.id == body.level_id).first()
    if level is None:
        raise HTTPException(status_code=404, detail=f"Level {body.level_id} not found.")
    siblings = db.query(Level).filter(Level.world_id == level.world_id).all()
    if level_states(db, player, siblings)[level.id][0] == "locked":
        raise HTTPException(status_code=403, detail="That level is still locked.")
    enemy = db.query(Enemy).filter(Enemy.id == level.enemy_id).first()
    question = db.query(Question).filter(Question.id == level.question_id).first()
    if enemy is None or question is None:
        raise HTTPException(status_code=404, detail="Level is missing its enemy or question.")

    started_at = datetime.now(timezone.utc)
    time_limit_s = TIME_LIMIT_BY_DIFFICULTY.get(level.difficulty, 300)
    battle = Battle(
        player_id=player.id, level_id=level.id, enemy_id=enemy.id, question_id=question.id,
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


def _owned_battle(db: Session, battle_id: int, player: Player) -> Battle:
    battle = db.query(Battle).filter(Battle.id == battle_id).first()
    if battle is None:
        raise HTTPException(status_code=404, detail=f"Battle {battle_id} not found.")
    if battle.player_id != player.id:
        raise HTTPException(status_code=403, detail="That battle belongs to another player.")
    return battle


_judge = judge_question


@router.post("/api/battles/{battle_id}/run", response_model=BattleRunOut)
def run_battle(battle_id: int, body: CodeSubmitIn, player: Player = Depends(get_current_player), db: Session = Depends(get_db)):
    battle = _owned_battle(db, battle_id, player)
    if battle.status != "in_progress":
        raise HTTPException(status_code=400, detail=f"Battle {battle_id} is already {battle.status}.")
    question = db.query(Question).filter(Question.id == battle.question_id).first()

    results, passed_tests, total_tests = _judge(question, body.code, body.language)
    correctness_percent = round(100 * passed_tests / total_tests) if total_tests else 0

    return BattleRunOut(
        passed_tests=passed_tests, total_tests=total_tests, results=results,
        correctness_percent=correctness_percent,
    )


@router.post("/api/battles/{battle_id}/submit", response_model=BattleSubmitOut)
def submit_battle(battle_id: int, body: CodeSubmitIn, player: Player = Depends(get_current_player), db: Session = Depends(get_db)):
    battle = _owned_battle(db, battle_id, player)
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

    regen_hp(player)
    hp_lost = round((100 - correctness_percent) / 100 * 10)
    player.hp = max(0, player.hp - hp_lost)
    player.hp_updated_at = datetime.now(timezone.utc).replace(tzinfo=None)

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
        complete_level(db, player, level, stars)
        xp_earned = level.xp_reward
        gold_earned = level.gold_reward
        award_xp(player, xp_earned, gold_earned)
        award_badges(db, player)
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
