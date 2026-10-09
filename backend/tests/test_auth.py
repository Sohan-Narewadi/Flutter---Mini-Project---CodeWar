def test_create_player_returns_token(client):
    r = client.post("/api/players", json={"name": "Sohan"})
    assert r.status_code == 201
    body = r.json()
    assert body["token"] and body["player_id"] > 0
    assert body["player"]["display_name"] == "Sohan"


def test_duplicate_name_case_insensitive_409(client):
    client.post("/api/players", json={"name": "Sohan"})
    assert client.post("/api/players", json={"name": "sohan"}).status_code == 409


def test_name_length_validation(client):
    assert client.post("/api/players", json={"name": "a"}).status_code == 422
    assert client.post("/api/players", json={"name": "x" * 17}).status_code == 422


def test_get_player_requires_token(client):
    assert client.get("/api/player").status_code == 401
    assert client.get("/api/player", headers={"Authorization": "Bearer nope"}).status_code == 401
    assert client.get("/api/player", headers={"Authorization": "garbage"}).status_code == 401


def test_get_player_with_token(client):
    tok = client.post("/api/players", json={"name": "Ada"}).json()["token"]
    r = client.get("/api/player", headers={"Authorization": f"Bearer {tok}"})
    assert r.status_code == 200 and r.json()["display_name"] == "Ada"


def test_token_not_stored_raw(client):
    from app.models import Player
    tok = client.post("/api/players", json={"name": "Ada"}).json()["token"]
    db = client.SessionLocal()
    p = db.query(Player).first()
    assert p.token_hash and p.token_hash != tok
    db.close()
