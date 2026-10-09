import pytest

from app.tiers import tier_for


@pytest.mark.parametrize("rating,key", [
    (0, "iron"), (899, "iron"), (900, "bronze"), (1000, "bronze"), (1099, "bronze"),
    (1100, "silver"), (1299, "silver"), (1300, "gold"), (1499, "gold"),
    (1500, "platinum"), (1699, "platinum"), (1700, "diamond"), (5000, "diamond"),
])
def test_tier_boundaries(rating, key):
    assert tier_for(rating)["key"] == key


def test_tier_reports_next_threshold():
    assert tier_for(1000)["next_min"] == 1100
    assert tier_for(1700)["next_min"] is None


def test_default_rating_is_bronze_and_api_exposes_tier(auth_client):
    me = auth_client.get("/api/player").json()
    assert me["rating"] == 1000 and me["tier"] == "bronze"
    lb = auth_client.get("/api/leaderboard").json()
    assert lb["me"]["tier"] == "bronze"
    assert all("tier" in e for e in lb["entries"])
