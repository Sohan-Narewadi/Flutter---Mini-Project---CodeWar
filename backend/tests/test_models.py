from app.models import Player


def test_insert_and_query_player(client):
    db = client.SessionLocal()
    player = db.query(Player).filter(Player.id == 1).first()
    assert player.username == "codeknight"
    assert player.level == 12
    db.close()
