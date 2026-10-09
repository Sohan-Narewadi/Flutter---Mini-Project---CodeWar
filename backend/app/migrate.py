"""Tiny additive migration: adds columns that exist in the models but not yet
in an older SQLite database, so upgrading never requires deleting the file.
New tables are handled by `create_all`; this only covers new columns."""
from sqlalchemy import inspect, text

from app.database import Base


def _default_sql(col) -> str | None:
    d = col.default
    if d is None or not getattr(d, "is_scalar", False):
        return None
    v = d.arg
    if isinstance(v, bool):
        return "1" if v else "0"
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, str):
        return "'" + v.replace("'", "''") + "'"
    return None


def ensure_columns(engine) -> list[str]:
    """Returns the "table.column" names that were added."""
    added: list[str] = []
    insp = inspect(engine)
    with engine.begin() as conn:
        for table in Base.metadata.sorted_tables:
            if not insp.has_table(table.name):
                continue
            existing = {c["name"] for c in insp.get_columns(table.name)}
            for col in table.columns:
                if col.name in existing or col.primary_key:
                    continue
                ddl = f'ALTER TABLE "{table.name}" ADD COLUMN "{col.name}" {col.type.compile(engine.dialect)}'
                default = _default_sql(col)
                if default is not None:
                    ddl += f" DEFAULT {default}"
                if not col.nullable and default is not None:
                    ddl += " NOT NULL"
                conn.execute(text(ddl))
                added.append(f"{table.name}.{col.name}")
    return added


def backfill_after_upgrade(engine, added: list[str]) -> bool:
    """One-time data repair, run only on the start that adds `best_streak`
    (i.e. the upgrade that introduced online-only records):

    * wins/losses used to include campaign battles; rebuild them from the
      real online results in `room_results` (a room where everyone tied has
      no winner or loser);
    * best_streak starts at the current streak instead of 0.

    Returns True when it ran."""
    if "players.best_streak" not in added:
        return False
    from sqlalchemy import text
    with engine.begin() as conn:
        tables = {r[0] for r in conn.execute(text("SELECT name FROM sqlite_master WHERE type='table'"))}
        if "room_results" in tables:
            conn.execute(text(
                "UPDATE players SET "
                "wins = (SELECT COUNT(*) FROM room_results r WHERE r.player_id = players.id AND r.rank = 1 "
                "        AND (SELECT COUNT(DISTINCT rank) FROM room_results x WHERE x.room_code = r.room_code) > 1), "
                "losses = (SELECT COUNT(*) FROM room_results r WHERE r.player_id = players.id AND r.rank > 1)"
            ))
        conn.execute(text("UPDATE players SET best_streak = streak WHERE best_streak < streak"))
    return True
