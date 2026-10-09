from pydantic import computed_field, BaseModel, ConfigDict, field_validator
from app.tiers import tier_for

# Only this many example test cases are shown to players; the rest are
# hidden judge cases so a lookup table of the examples cannot pass.
VISIBLE_TEST_CASES = 3


class PlayerOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    username: str
    display_name: str
    level: int
    xp: int
    xp_to_next: int
    hp: int
    hp_max: int
    gold: int
    streak: int
    best_streak: int = 0
    rating: int = 1000
    wins: int = 0
    losses: int = 0

    @field_validator("best_streak", mode="before")
    @classmethod
    def _none_is_zero(cls, v):
        return 0 if v is None else v

    @computed_field
    @property
    def tier(self) -> str:
        return tier_for(self.rating)["key"]


class PlayerCreateIn(BaseModel):
    name: str


class PlayerCreateOut(BaseModel):
    player_id: int
    token: str
    player: PlayerOut


class WorldOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    name: str
    order: int
    description: str
    cleared_percent: int


class LevelOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    world_id: str
    order: int
    title: str
    difficulty: str
    status: str
    stars: int
    enemy_id: str
    xp_reward: int
    gold_reward: int


class EnemyOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    name: str
    level: int
    difficulty: str
    hp_max: int
    hp_current: int
    vulnerability: str
    tier: str
    locked: bool
    unlock_hint: str
    xp_reward: int
    gold_reward: int
    defeated: bool = False


class TestCaseOut(BaseModel):
    input: str
    expected_output: str


class QuestionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    title: str
    difficulty: str
    tags: list[str]
    prompt: str
    example_input: str
    example_output: str
    starter_code: dict[str, str]
    test_cases: list[TestCaseOut]

    @field_validator("test_cases", mode="before")
    @classmethod
    def _only_visible(cls, v):
        return list(v)[:VISIBLE_TEST_CASES]


class GeneratedQuestionOut(QuestionOut):
    topic: str = ""
    source: str = "seed"


class GenerateIn(BaseModel):
    difficulty: str
    topic: str | None = None


class TopicOut(BaseModel):
    id: str
    label: str


class BattleStartIn(BaseModel):
    level_id: int


class BattleStartOut(BaseModel):
    battle_id: int
    enemy_hp_remaining: int
    time_limit_s: int
    started_at: str
    question: QuestionOut


class CodeSubmitIn(BaseModel):
    code: str
    language: str = "python"


class TestResultOut(BaseModel):
    input: str
    expected: str
    actual: str
    passed: bool
    duration_ms: float


class BattleRunOut(BaseModel):
    passed_tests: int
    total_tests: int
    results: list[TestResultOut]
    correctness_percent: int


class BattleSubmitOut(BattleRunOut):
    outcome: str
    xp_earned: int = 0
    gold_earned: int = 0
    hp_lost: int = 0
    damage_dealt: int = 0
    enemy_hp_remaining: int = 0
    enemy_hp_max: int = 0
    enemy_defeated: bool = False
    is_new_best: bool = False
    best_score_percent: int = 0


class RoomCreateIn(BaseModel):
    mode: str = "race"
    difficulty: str = "easy"
    language: str = "python"


class LeaderboardEntry(BaseModel):
    rank: int
    player_id: int
    name: str
    level: int
    rating: int
    value: int
    is_me: bool = False

    @computed_field
    @property
    def tier(self) -> str:
        return tier_for(self.rating)["key"]


class LeaderboardOut(BaseModel):
    scope: str
    metric: str
    entries: list[LeaderboardEntry]
    me: LeaderboardEntry


class FriendIn(BaseModel):
    name: str


class PracticeNextIn(BaseModel):
    difficulty: str = "easy"
    topic: str | None = None
    daily: bool = False


class PracticeNextOut(BaseModel):
    practice_id: int
    daily: bool = False
    question: GeneratedQuestionOut


class PracticeSubmitOut(BattleRunOut):
    solved: bool
    xp_earned: int = 0
    gold_earned: int = 0
    streak: int = 0
    hints_used: int = 0
    new_badges: list[dict] = []


class HintOut(BaseModel):
    level: int
    hint: str


class TopicStatOut(BaseModel):
    id: str
    label: str
    solved: int
    mastery_percent: int


class PracticeStatsOut(BaseModel):
    streak: int
    solved_today: int
    total_solved: int = 0
    daily_done: bool = False
    daily_resets_in: int = 0  # seconds until the daily challenge changes
    topics: list[TopicStatOut]
