from app.models import Player


def test_insert_and_query_player(auth_client):
    db = auth_client.SessionLocal()
    player = db.query(Player).filter(Player.id == auth_client.player_id).first()
    assert player.username == "tester"
    assert player.level == 1
    assert player.rating == 1000
    db.close()
