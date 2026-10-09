from app.models import Player, World, Level, Enemy, Question


def test_seed_creates_expected_counts(client):
    db = client.SessionLocal()
    assert db.query(Player).count() == 0  # players register themselves
    assert db.query(World).count() == 1
    assert db.query(Level).count() == 8
    assert db.query(Enemy).count() == 6
    assert db.query(Question).count() == 2
    db.close()


def test_seed_is_idempotent(client):
    from app.seed import seed_if_empty
    db = client.SessionLocal()
    seed_if_empty(db)  # second call, DB already seeded
    assert db.query(Level).count() == 8  # unchanged, not doubled
    db.close()


def test_level_ids_are_integers_for_battle_start(client):
    # This is the exact bug this backend fixes: seed_data.dart's ids ("n1".."n8")
    # aren't parseable as int, so GameState.startBattle() always threw
    # "This encounter has no backend level to battle against." Real backend
    # level ids must be plain integers.
    db = client.SessionLocal()
    level = db.query(Level).filter(Level.order == 3).first()
    assert isinstance(level.id, int)
    db.close()
