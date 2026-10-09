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
