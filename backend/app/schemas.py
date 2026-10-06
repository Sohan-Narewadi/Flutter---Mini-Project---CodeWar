from pydantic import BaseModel, ConfigDict


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
