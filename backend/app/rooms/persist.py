"""Writes a finished room's outcome: ratings, XP, win/loss, friend links."""
from sqlalchemy.orm import Session

from app.models.player import Player
from app.models.room import RoomResult
from app.models.social import Friend
from app.progress import award_xp
from app.rooms.rating import update_ratings

BASE_XP = {"easy": 30, "medium": 60, "hard": 120}
RANK_SHARE = {1: 1.0, 2: 0.6}  # everyone else gets 0.3


def persist_results(
    db: Session, code: str, mode: str, difficulty: str, reason: str | None, standings: list[dict],
) -> dict[int, dict]:
    """Applies results and returns {player_id: {"rating_delta", "xp", "gold"}}."""
    players = {p.id: p for p in db.query(Player).filter(Player.id.in_([s["player_id"] for s in standings])).all()}
    entries = [(s["player_id"], players[s["player_id"]].rating, s["rank"]) for s in standings if s["player_id"] in players]
    deltas = update_ratings(entries)
    all_tied = len({s["rank"] for s in standings}) == 1
    rewards: dict[int, dict] = {}

    for s in standings:
        player = players.get(s["player_id"])
        if player is None:
            continue
        rating_before = player.rating
        delta = deltas.get(player.id, 0)
        player.rating = max(0, player.rating + delta)

        won = s["rank"] == 1 and not all_tied
        if not all_tied:
            if won:
                player.wins += 1
            else:
                player.losses += 1

        xp = 0
        earned_something = s["best_pct"] > 0 or (reason == "forfeit" and won)
        if earned_something and not s["forfeited"]:
            xp = round(BASE_XP[difficulty] * RANK_SHARE.get(s["rank"], 0.3))
        gold = xp // 4
        if xp or gold:
            award_xp(player, xp, gold)

        db.add(RoomResult(
            room_code=code, mode=mode, player_id=player.id, rank=s["rank"], best_pct=s["best_pct"],
            rating_before=rating_before, rating_delta=delta, xp=xp, gold=gold,
        ))
        rewards[player.id] = {"rating_delta": delta, "xp": xp, "gold": gold, "rating": player.rating}

    ids = [s["player_id"] for s in standings]
    for a in ids:
        for b in ids:
            if a != b and db.query(Friend).filter(Friend.player_id == a, Friend.friend_id == b).first() is None:
                db.add(Friend(player_id=a, friend_id=b))
    db.commit()
    return rewards
