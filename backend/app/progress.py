"""Per-player progress helpers: HP regeneration, level status, unlocks."""
from datetime import date, datetime, timezone

from sqlalchemy.orm import Session

from app.models.level import Level
from app.models.progress import PlayerLevel

HP_REGEN_SECONDS = 30


def current_week(today: date | None = None) -> str:
    iso = (today or date.today()).isocalendar()
    return f"{iso.year}-W{iso.week:02d}"


def award_xp(player, xp: int, gold: int) -> None:
    """Adds XP/gold, tracks lifetime and weekly XP, and handles level-ups."""
    player.xp += xp
    player.gold += gold
    player.total_xp = (player.total_xp or 0) + xp
    week = current_week()
    if player.weekly_week != week:
        player.weekly_week = week
        player.weekly_xp = 0
    player.weekly_xp = (player.weekly_xp or 0) + xp
    while player.xp >= player.xp_to_next:
        player.xp -= player.xp_to_next
        player.level += 1
        player.xp_to_next = round(player.xp_to_next * 1.2)


def _naive_utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def regen_hp(player, now: datetime | None = None) -> None:
    """+1 HP per HP_REGEN_SECONDS since hp_updated_at, capped at hp_max."""
    now = now or _naive_utcnow()
    last = player.hp_updated_at or now
    if player.hp >= player.hp_max:
        player.hp_updated_at = now
        return
    ticks = int((now - last).total_seconds() // HP_REGEN_SECONDS)
    if ticks > 0:
        player.hp = min(player.hp_max, player.hp + ticks)
        player.hp_updated_at = last + _seconds(ticks * HP_REGEN_SECONDS)
        if player.hp >= player.hp_max:
            player.hp_updated_at = now


def _seconds(n: int):
    from datetime import timedelta
    return timedelta(seconds=n)


def level_states(db: Session, player, levels: list[Level]) -> dict[int, tuple[str, int]]:
    """Returns {level_id: (status, stars)} for this player.

    Default: the first level (lowest order) of each world is "current", the
    rest "locked". PlayerLevel rows override.
    """
    rows = {
        r.level_id: r
        for r in db.query(PlayerLevel).filter(PlayerLevel.player_id == player.id).all()
    }
    first_in_world: dict[str, int] = {}
    for lv in levels:
        cur = first_in_world.get(lv.world_id)
        if cur is None or lv.order < cur:
            first_in_world[lv.world_id] = lv.order
    out: dict[int, tuple[str, int]] = {}
    for lv in levels:
        row = rows.get(lv.id)
        if row is not None:
            out[lv.id] = (row.status, row.stars)
        elif lv.order == first_in_world[lv.world_id]:
            out[lv.id] = ("current", 0)
        else:
            out[lv.id] = ("locked", 0)
    return out


def _row(db: Session, player, level_id: int) -> PlayerLevel:
    row = (
        db.query(PlayerLevel)
        .filter(PlayerLevel.player_id == player.id, PlayerLevel.level_id == level_id)
        .first()
    )
    if row is None:
        row = PlayerLevel(player_id=player.id, level_id=level_id, status="locked", stars=0)
        db.add(row)
    return row


def complete_level(db: Session, player, level: Level, stars: int) -> None:
    row = _row(db, player, level.id)
    row.status = "completed"
    row.stars = max(row.stars or 0, stars)
    nxt = (
        db.query(Level)
        .filter(Level.world_id == level.world_id, Level.order > level.order)
        .order_by(Level.order)
        .first()
    )
    if nxt is not None:
        nrow = _row(db, player, nxt.id)
        if nrow.status == "locked":
            nrow.status = "current"
    db.flush()


def cleared_percent(db: Session, player, world_id: str) -> int:
    levels = db.query(Level).filter(Level.world_id == world_id).all()
    if not levels:
        return 0
    states = level_states(db, player, levels)
    done = sum(1 for lv in levels if states[lv.id][0] == "completed")
    return round(100 * done / len(levels))
