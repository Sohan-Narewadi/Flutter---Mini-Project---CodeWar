from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.auth import get_current_player
from app.badges import BADGES, award_badges, badge_view
from app.database import get_db
from app.models.badge import PlayerBadge
from app.models.player import Player
from app.models.room import RoomResult
from app.tiers import tier_for

router = APIRouter()


@router.get("/api/badges")
def my_badges(player: Player = Depends(get_current_player), db: Session = Depends(get_db)):
    """The full catalogue with `earned_at` set for badges this player earned.
    Also back-fills badges earned before this feature existed."""
    award_badges(db, player)
    db.commit()
    earned = {b.key: b.earned_at for b in db.query(PlayerBadge).filter(PlayerBadge.player_id == player.id).all()}
    return [badge_view(key, earned.get(key)) for key in BADGES]


@router.get("/api/matches")
def my_matches(
    limit: int = Query(20, ge=1, le=100),
    player: Player = Depends(get_current_player),
    db: Session = Depends(get_db),
):
    """The caller's finished online matches, newest first."""
    mine = (
        db.query(RoomResult)
        .filter(RoomResult.player_id == player.id)
        .order_by(RoomResult.finished_at.desc(), RoomResult.id.desc())
        .limit(limit)
        .all()
    )
    out = []
    for r in mine:
        others = (
            db.query(RoomResult, Player)
            .join(Player, Player.id == RoomResult.player_id)
            .filter(RoomResult.room_code == r.room_code, RoomResult.player_id != player.id)
            .order_by(RoomResult.rank)
            .all()
        )
        out.append({
            "room_code": r.room_code,
            "mode": r.mode,
            "rank": r.rank,
            "players_count": len(others) + 1,
            "best_pct": r.best_pct,
            "rating_before": r.rating_before,
            "rating_delta": r.rating_delta,
            "xp": r.xp,
            "gold": r.gold,
            "opponents": [p.display_name for _, p in others[:3]],
            "finished_at": r.finished_at.isoformat() + "Z",
        })
    return out


@router.get("/api/players/{player_id}/public")
def public_profile(player_id: int, _: Player = Depends(get_current_player), db: Session = Depends(get_db)):
    """What anyone signed in may see about a player. No token, gold, HP or
    login name."""
    p = db.query(Player).filter(Player.id == player_id).first()
    if p is None:
        raise HTTPException(status_code=404, detail="No such player.")
    badges = [b.key for b in db.query(PlayerBadge).filter(PlayerBadge.player_id == p.id).order_by(PlayerBadge.earned_at).all()]
    return {
        "id": p.id,
        "name": p.display_name,
        "level": p.level,
        "rating": p.rating or 0,
        "tier": tier_for(p.rating or 0)["key"],
        "wins": p.wins or 0,
        "losses": p.losses or 0,
        "total_xp": p.total_xp or 0,
        "badges": badges,
        "joined": p.created_at.isoformat() + "Z" if p.created_at else None,
    }
