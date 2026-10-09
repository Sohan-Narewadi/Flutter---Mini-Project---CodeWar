"""Achievements. Every badge is earned from REAL data (rows in the database),
never granted for free. `award_badges` is idempotent and cheap enough to call
after any event that can change the inputs."""
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.badge import PlayerBadge
from app.models.player import Player
from app.models.practice import PracticeAttempt, PracticeStat
from app.models.progress import PlayerLevel
from app.models.room import RoomResult

# key -> metadata + predicate over the stats dict built in `_stats`.
BADGES: dict[str, dict] = {
    "first_solve": {"name": "First Blood", "description": "Solve your first problem.", "icon": "flag",
                    "test": lambda s: s["solved"] + s["levels_done"] >= 1},
    "solve_10": {"name": "Warming Up", "description": "Solve 10 practice problems.", "icon": "local_fire_department",
                 "test": lambda s: s["solved"] >= 10},
    "solve_100": {"name": "Centurion", "description": "Solve 100 practice problems.", "icon": "military_tech",
                  "test": lambda s: s["solved"] >= 100},
    "hard_solver": {"name": "Hard Mode", "description": "Solve a Hard practice problem.", "icon": "whatshot",
                    "test": lambda s: s["hard_solved"] >= 1},
    "daily_done": {"name": "Daily Driver", "description": "Complete a daily challenge.", "icon": "today",
                   "test": lambda s: s["daily_done"]},
    "topic_master": {"name": "Topic Master", "description": "Reach 100% mastery in any topic.", "icon": "school",
                     "test": lambda s: s["topic_master"]},
    "streak_3": {"name": "On a Roll", "description": "Reach a 3-day streak.", "icon": "bolt",
                 "test": lambda s: s["best_streak"] >= 3},
    "streak_7": {"name": "Week Warrior", "description": "Reach a 7-day streak.", "icon": "date_range",
                 "test": lambda s: s["best_streak"] >= 7},
    "streak_30": {"name": "Unstoppable", "description": "Reach a 30-day streak.", "icon": "calendar_month",
                  "test": lambda s: s["best_streak"] >= 30},
    "first_win": {"name": "Victor", "description": "Win an online match.", "icon": "emoji_events",
                  "test": lambda s: s["wins"] >= 1},
    "win_5": {"name": "Contender", "description": "Win 5 online matches.", "icon": "workspace_premium",
              "test": lambda s: s["wins"] >= 5},
    "win_25": {"name": "Champion", "description": "Win 25 online matches.", "icon": "stars",
               "test": lambda s: s["wins"] >= 25},
    "rival": {"name": "Rival", "description": "Play 10 online matches.", "icon": "groups",
              "test": lambda s: s["rooms"] >= 10},
    "climber": {"name": "Climber", "description": "Reach Silver tier (1100 rating).", "icon": "trending_up",
                "test": lambda s: s["rating"] >= 1100},
    "level_5": {"name": "Level 5", "description": "Reach player level 5.", "icon": "looks_5",
                "test": lambda s: s["level"] >= 5},
    "level_10": {"name": "Level 10", "description": "Reach player level 10.", "icon": "filter_9_plus",
                 "test": lambda s: s["level"] >= 10},
    "campaign_5": {"name": "Pathfinder", "description": "Clear 5 campaign levels.", "icon": "map",
                   "test": lambda s: s["levels_done"] >= 5},
}


def _stats(db: Session, player: Player) -> dict:
    solved = (
        db.query(func.coalesce(func.sum(PracticeStat.solved), 0)).filter(PracticeStat.player_id == player.id).scalar()
    )
    solved_attempts = db.query(PracticeAttempt).filter(
        PracticeAttempt.player_id == player.id, PracticeAttempt.status == "solved"
    )
    return {
        "solved": int(solved or 0),
        "levels_done": db.query(PlayerLevel)
        .filter(PlayerLevel.player_id == player.id, PlayerLevel.status == "completed")
        .count(),
        "hard_solved": solved_attempts.filter(PracticeAttempt.difficulty == "hard").count(),
        "daily_done": solved_attempts.filter(PracticeAttempt.daily.is_(True)).first() is not None,
        "topic_master": db.query(PracticeStat)
        .filter(PracticeStat.player_id == player.id, PracticeStat.points >= 100)
        .first()
        is not None,
        "best_streak": max(player.best_streak or 0, player.streak or 0),
        "wins": player.wins or 0,
        "rooms": db.query(RoomResult).filter(RoomResult.player_id == player.id).count(),
        "rating": player.rating or 0,
        "level": player.level or 1,
    }


def award_badges(db: Session, player: Player) -> list[str]:
    """Inserts any newly satisfied badges (flushes, does not commit) and
    returns their keys in catalogue order."""
    db.flush()
    have = {k for (k,) in db.query(PlayerBadge.key).filter(PlayerBadge.player_id == player.id).all()}
    stats = _stats(db, player)
    new = [key for key, b in BADGES.items() if key not in have and b["test"](stats)]
    for key in new:
        db.add(PlayerBadge(player_id=player.id, key=key))
    if new:
        db.flush()
    return new


def badge_view(key: str, earned_at=None) -> dict:
    b = BADGES[key]
    return {
        "key": key,
        "name": b["name"],
        "description": b["description"],
        "icon": b["icon"],
        "earned_at": earned_at.isoformat() + "Z" if earned_at else None,
    }
