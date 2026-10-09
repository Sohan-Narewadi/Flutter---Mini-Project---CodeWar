from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import Base, engine, SessionLocal
from app import models  # noqa: F401 (registers models with Base.metadata)
from app.migrate import ensure_columns
from app.seed import seed_if_empty
from app.routers import player, worlds, levels, enemies, questions, battles, leaderboard, practice, rooms, profile


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    ensure_columns(engine)
    db = SessionLocal()
    try:
        seed_if_empty(db)
    finally:
        db.close()
    yield


app = FastAPI(title="CodeWar Backend", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(player.router)
app.include_router(worlds.router)
app.include_router(levels.router)
app.include_router(enemies.router)
app.include_router(questions.router)
app.include_router(battles.router)
app.include_router(leaderboard.router)
app.include_router(practice.router)
app.include_router(rooms.router)
app.include_router(profile.router)


@app.get("/health")
def health():
    return {"status": "ok"}
