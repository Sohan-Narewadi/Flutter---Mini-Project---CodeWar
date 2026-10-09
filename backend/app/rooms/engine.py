"""Room state machine. Pure logic: no I/O, no clock, no sockets.

Every method that depends on time takes `now` (seconds, any monotonic
origin) so tests can drive a fake clock. The server owns the clock and the
scoring; clients only report that they ran code, never what the result was
(the manager runs the judge itself and calls `submit` with its numbers).
"""
from dataclasses import dataclass

COUNTDOWN_S = 3.0
DISCONNECT_GRACE_S = 30.0
MAX_PLAYERS = {"race": 8, "duel": 2}
TIME_LIMIT_S = {"easy": 300, "medium": 480, "hard": 720}
_INF = float("inf")


class RoomError(Exception):
    def __init__(self, code: str, message: str | None = None):
        super().__init__(message or code)
        self.code = code
        self.message = message or code


@dataclass
class Member:
    player_id: int
    name: str
    seq: int
    connected: bool = True
    disconnected_at: float | None = None
    passed: int = 0
    total: int = 0
    best_pct: int = 0
    best_at: float | None = None
    submissions: int = 0
    forfeited: bool = False


class Room:
    def __init__(
        self,
        code: str,
        mode: str,
        difficulty: str,
        language: str,
        host_id: int,
        host_name: str,
        now: float,
        countdown_s: float = COUNTDOWN_S,
        grace_s: float = DISCONNECT_GRACE_S,
    ):
        if mode not in MAX_PLAYERS:
            raise ValueError(f"Unknown mode {mode!r}")
        if difficulty not in TIME_LIMIT_S:
            raise ValueError(f"Unknown difficulty {difficulty!r}")
        self.code = code
        self.mode = mode
        self.difficulty = difficulty
        self.language = language
        self.host_id = host_id
        self.created_at = now
        self.countdown_s = countdown_s
        self.grace_s = grace_s
        self.time_limit_s = TIME_LIMIT_S[difficulty]
        self.status = "lobby"  # lobby | countdown | running | finished
        self.closed = False
        self.started_at: float | None = None
        self.countdown_ends_at: float | None = None
        self.finished_at: float | None = None
        self.finish_reason: str | None = None
        self._seq = 0
        self.members: dict[int, Member] = {}
        self._add(host_id, host_name)

    # --- membership ----------------------------------------------------

    def _add(self, player_id: int, name: str) -> Member:
        self._seq += 1
        member = Member(player_id=player_id, name=name, seq=self._seq)
        self.members[player_id] = member
        return member

    def join(self, player_id: int, name: str, now: float) -> bool:
        """Returns True for a new member, False if they were already in."""
        existing = self.members.get(player_id)
        if existing is not None:
            existing.connected = True
            existing.disconnected_at = None
            return False
        if self.status != "lobby":
            raise RoomError("started", "That room has already started.")
        if len(self.members) >= MAX_PLAYERS[self.mode]:
            raise RoomError("full", "That room is full.")
        self._add(player_id, name)
        return True

    def leave(self, player_id: int, now: float) -> None:
        member = self.members.get(player_id)
        if member is None:
            return
        if self.status == "lobby":
            del self.members[player_id]
            if not self.members:
                self.closed = True
            elif player_id == self.host_id:
                self.host_id = min(self.members.values(), key=lambda m: m.seq).player_id
            return
        member.connected = False
        member.disconnected_at = now
        if self.status != "finished":
            member.forfeited = True

    def disconnect(self, player_id: int, now: float) -> None:
        member = self.members.get(player_id)
        if member is not None and member.connected:
            member.connected = False
            member.disconnected_at = now

    def reconnect(self, player_id: int) -> None:
        member = self.members.get(player_id)
        if member is not None and not member.forfeited:
            member.connected = True
            member.disconnected_at = None

    # --- lifecycle -----------------------------------------------------

    def check_can_start(self, player_id: int) -> None:
        if player_id != self.host_id:
            raise RoomError("not_host", "Only the host can start the match.")
        if self.status != "lobby":
            raise RoomError("started", "The match has already started.")
        if sum(1 for m in self.members.values() if m.connected) < 2:
            raise RoomError("need_players", "Wait for at least one more player.")

    def start(self, player_id: int, now: float) -> None:
        self.check_can_start(player_id)
        # Players who joined by code but never opened their socket are not in the match.
        for pid in [p for p, m in self.members.items() if not m.connected and p != self.host_id]:
            del self.members[pid]
        self.status = "countdown"
        self.countdown_ends_at = now + self.countdown_s

    def tick(self, now: float) -> list[str]:
        """Advances time-based transitions. Returns events such as 'running', 'finished'."""
        events: list[str] = []
        if self.status == "countdown" and now >= (self.countdown_ends_at or 0):
            self.status = "running"
            self.started_at = self.countdown_ends_at
            events.append("running")
        if self.status == "running":
            for m in self.members.values():
                if (
                    not m.connected and not m.forfeited and m.disconnected_at is not None
                    and now - m.disconnected_at > self.grace_s
                ):
                    m.forfeited = True
            active = [m for m in self.members.values() if not m.forfeited]
            if len(active) <= 1:
                self._finish(now, "forfeit")
                events.append("finished")
            elif now >= (self.started_at or 0) + self.time_limit_s:
                self._finish(now, "timeout")
                events.append("finished")
        return events

    def _finish(self, now: float, reason: str) -> None:
        self.status = "finished"
        self.finish_reason = reason
        self.finished_at = now

    def submit(self, player_id: int, passed: int, total: int, now: float) -> None:
        """Records a judged submission (numbers come from the server's judge)."""
        if self.status != "running":
            raise RoomError("not_running", "The match is not running.")
        member = self.members.get(player_id)
        if member is None:
            raise RoomError("not_member", "You are not in this room.")
        if member.forfeited:
            raise RoomError("forfeited", "You left this match.")
        if now >= (self.started_at or 0) + self.time_limit_s:
            self.tick(now)
            raise RoomError("not_running", "Time is up.")
        pct = round(100 * passed / total) if total else 0
        member.submissions += 1
        if pct > member.best_pct:
            member.best_pct = pct
            member.best_at = now
            member.passed = passed
            member.total = total
        if pct == 100:
            self._finish(now, "solved")

    # --- views ---------------------------------------------------------

    def standings(self) -> list[dict]:
        def key(m: Member):
            return (m.forfeited, -m.best_pct, m.best_at if m.best_at is not None else _INF)

        ordered = sorted(self.members.values(), key=lambda m: (key(m), m.seq))
        out: list[dict] = []
        for i, m in enumerate(ordered):
            rank = out[-1]["rank"] if out and key(ordered[i - 1]) == key(m) else i + 1
            out.append({
                "player_id": m.player_id, "name": m.name, "rank": rank, "best_pct": m.best_pct,
                "passed": m.passed, "total": m.total, "forfeited": m.forfeited,
                "time_s": None if m.best_at is None or self.started_at is None else round(m.best_at - self.started_at, 1),
            })
        return out

    def snapshot(self, now: float) -> dict:
        ranks = {s["player_id"]: s["rank"] for s in self.standings()}
        seconds_left = None
        countdown_left = None
        if self.status == "running" and self.started_at is not None:
            seconds_left = int(max(0, self.started_at + self.time_limit_s - now))
        if self.status == "countdown" and self.countdown_ends_at is not None:
            countdown_left = round(max(0.0, self.countdown_ends_at - now), 1)
        return {
            "code": self.code,
            "mode": self.mode,
            "difficulty": self.difficulty,
            "language": self.language,
            "status": self.status,
            "host_id": self.host_id,
            "max_players": MAX_PLAYERS[self.mode],
            "time_limit_s": self.time_limit_s,
            "seconds_left": seconds_left,
            "countdown_left": countdown_left,
            "reason": self.finish_reason,
            "players": [
                {
                    "player_id": m.player_id, "name": m.name, "connected": m.connected,
                    "is_host": m.player_id == self.host_id, "passed": m.passed, "total": m.total,
                    "best_pct": m.best_pct, "submissions": m.submissions, "forfeited": m.forfeited,
                    "rank": ranks[m.player_id] if self.status in ("running", "finished") else None,
                }
                for m in sorted(self.members.values(), key=lambda m: m.seq)
            ],
            "standings": self.standings() if self.status == "finished" else None,
        }
