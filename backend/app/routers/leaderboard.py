from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app.auth import get_current_player
from app.database import get_db
from app.models.player import Player
from app.models.social import Friend
from app.progress import current_week
from app.schemas import FriendIn, LeaderboardEntry, LeaderboardOut

router = APIRouter()

SCOPES = ("global", "weekly", "friends")
METRICS = ("xp", "rating")


def _value(p: Player, scope: str, metric: str, week: str) -> int:
    if scope == "weekly":
        return (p.weekly_xp or 0) if p.weekly_week == week else 0
    return (p.rating or 0) if metric == "rating" else (p.total_xp or 0)


@router.get("/api/leaderboard", response_model=LeaderboardOut)
def leaderboard(
    scope: str = "global",
    metric: str = "xp",
    limit: int = Query(50, ge=1, le=100),
    player: Player = Depends(get_current_player),
    db: Session = Depends(get_db),
):
    if scope not in SCOPES:
        raise HTTPException(status_code=422, detail=f"scope must be one of {list(SCOPES)}.")
    if metric not in METRICS:
        raise HTTPException(status_code=422, detail=f"metric must be one of {list(METRICS)}.")

    query = db.query(Player)
    if scope == "friends":
        friend_ids = [f.friend_id for f in db.query(Friend).filter(Friend.player_id == player.id).all()]
        query = query.filter(or_(Player.id == player.id, Player.id.in_(friend_ids)))
    players = query.all()

    week = current_week()
    scored = sorted(
        ((_value(p, scope, metric, week), p) for p in players),
        key=lambda vp: (-vp[0], -vp[1].level, vp[1].id),
    )
    entries = [
        LeaderboardEntry(
            rank=i + 1, player_id=p.id, name=p.display_name, level=p.level,
            rating=p.rating or 0, value=value, is_me=(p.id == player.id),
        )
        for i, (value, p) in enumerate(scored)
    ]
    me = next(e for e in entries if e.is_me)
    return LeaderboardOut(scope=scope, metric=metric, entries=entries[:limit], me=me)


@router.post("/api/friends")
def add_friend(body: FriendIn, player: Player = Depends(get_current_player), db: Session = Depends(get_db)):
    other = db.query(Player).filter(func.lower(Player.username) == body.name.strip().lower()).first()
    if other is None:
        raise HTTPException(status_code=404, detail="No player with that name.")
    if other.id == player.id:
        raise HTTPException(status_code=400, detail="You cannot add yourself.")
    for a, b in ((player.id, other.id), (other.id, player.id)):
        exists = db.query(Friend).filter(Friend.player_id == a, Friend.friend_id == b).first()
        if exists is None:
            db.add(Friend(player_id=a, friend_id=b))
    db.commit()
    return {"friend": other.display_name}
