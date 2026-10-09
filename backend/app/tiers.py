"""Rank tiers derived from the Elo rating. Thresholds are mirrored in the app
(`frontend/codewar/lib/models/tier.dart`); keep both in sync."""

TIERS = [
    ("iron", "Iron", 0),
    ("bronze", "Bronze", 900),
    ("silver", "Silver", 1100),
    ("gold", "Gold", 1300),
    ("platinum", "Platinum", 1500),
    ("diamond", "Diamond", 1700),
]


def tier_for(rating: int) -> dict:
    rating = rating or 0
    index = 0
    for i, (_, _, minimum) in enumerate(TIERS):
        if rating >= minimum:
            index = i
    key, name, minimum = TIERS[index]
    next_min = TIERS[index + 1][2] if index + 1 < len(TIERS) else None
    return {"key": key, "name": name, "min": minimum, "next_min": next_min}
