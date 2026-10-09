def test_get_player(auth_client):
    res = auth_client.get("/api/player")
    assert res.status_code == 200
    body = res.json()
    assert body["username"] == "tester"
    assert body["level"] == 1


def test_get_worlds(auth_client):
    res = auth_client.get("/api/worlds")
    assert res.status_code == 200
    body = res.json()
    assert len(body) == 1
    assert body[0]["id"] == "w2"


def test_get_levels_for_world(auth_client):
    res = auth_client.get("/api/levels", params={"world_id": "w2"})
    assert res.status_code == 200
    body = res.json()
    assert len(body) == 8
    assert body[0]["title"] == "Syntax Verification"
    assert "question_id" not in body[0]


def test_get_enemies(auth_client):
    res = auth_client.get("/api/enemies")
    assert res.status_code == 200
    assert len(res.json()) == 6


def test_get_question_by_id(auth_client):
    res = auth_client.get("/api/questions/q_two_sum")
    assert res.status_code == 200
    assert res.json()["title"] == "Two Sum Encounter"


def test_get_question_unknown_id(auth_client):
    res = auth_client.get("/api/questions/nope")
    assert res.status_code == 404
    assert "detail" in res.json()
