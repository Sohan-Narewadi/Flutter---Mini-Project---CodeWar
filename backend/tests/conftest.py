import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import Base, get_db
from app import models  # noqa: F401 (registers all models with Base.metadata)
from app.seed import seed_if_empty
from app.main import app


@pytest.fixture()
def client(tmp_path):
    # A real file (one connection per session) rather than a shared in-memory
    # connection: rooms persist results from worker threads, and sessions
    # sharing one connection would roll each other back.
    engine = create_engine(
        f"sqlite:///{tmp_path / 'test.db'}", connect_args={"check_same_thread": False},
    )
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)

    seed_db = TestingSessionLocal()
    seed_if_empty(seed_db)
    seed_db.close()

    def override_get_db():
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db
    from app.rooms.manager import manager
    manager.reset()
    with TestClient(app) as c:
        c.SessionLocal = TestingSessionLocal
        yield c
        manager.reset()
    app.dependency_overrides.clear()
    engine.dispose()


@pytest.fixture()
def auth_client(client):
    """client with a freshly created player's bearer token preset."""
    body = client.post("/api/players", json={"name": "Tester"}).json()
    client.headers["Authorization"] = f"Bearer {body['token']}"
    client.player_id = body["player_id"]
    # Older battle tests start level 3; open it for this player.
    from app.models import PlayerLevel
    db = client.SessionLocal()
    db.add(PlayerLevel(player_id=body["player_id"], level_id=3, status="current", stars=0))
    db.commit()
    db.close()
    return client


@pytest.fixture()
def make_player(client):
    """Returns a function creating a player; result: (player_id, headers)."""
    def _make(name):
        body = client.post("/api/players", json={"name": name}).json()
        return body["player_id"], {"Authorization": f"Bearer {body['token']}"}
    return _make
