"""Elo-style rating updates for rooms of 2 or more players."""

K_FACTOR = 32


def update_ratings(entries: list[tuple[int, int, int]]) -> dict[int, int]:
    """entries: (player_id, rating, rank). Equal rank = tie.

    Each player is compared pairwise with every other player (win=1, tie=0.5,
    loss=0) against the Elo expectation, then averaged over opponents so a big
    room does not swing ratings more than a duel. Returns {player_id: delta}.
    """
    n = len(entries)
    if n < 2:
        return {pid: 0 for pid, _, _ in entries}
    deltas: dict[int, int] = {}
    for pid, rating, rank in entries:
        total = 0.0
        for other_id, other_rating, other_rank in entries:
            if other_id == pid:
                continue
            score = 1.0 if rank < other_rank else (0.5 if rank == other_rank else 0.0)
            expected = 1.0 / (1.0 + 10 ** ((other_rating - rating) / 400))
            total += score - expected
        deltas[pid] = round(K_FACTOR / (n - 1) * total)
    return deltas
