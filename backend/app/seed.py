from sqlalchemy.orm import Session

from app.models.player import Player
from app.models.world import World
from app.models.level import Level
from app.models.enemy import Enemy
from app.models.question import Question


def seed_if_empty(db: Session) -> None:
    if db.query(Player).first() is not None:
        return

    db.add(Player(
        id=1, username="codeknight", display_name="CodeKnight",
        level=12, xp=600, xp_to_next=1000, hp=800, hp_max=1000, gold=1240, streak=7,
    ))

    db.add(World(
        id="w2", name="Array Ruins", order=2,
        description="Sector 2 · Corrupted array structures roam these ruins.",
        cleared_percent=50,
    ))

    db.add(Question(
        id="q_find_max", title="Find Maximum Element", difficulty="Easy",
        tags=["Arrays", "Two Pointers"],
        prompt="Given an integer array nums, return the greatest integer. Optimize for O(n) time and O(1) space.",
        example_input="nums = [3, 7, 2, 9, 4]", example_output="9",
        starter_code={
            "python": (
                "def find_maximum(nums: list[int]) -> int:\n"
                "    # TODO: return the greatest value in nums (or None if nums is empty)\n"
                "    pass"
            ),
            "typescript": (
                "function findMaximum(nums: number[]): number | null {\n"
                "  // TODO: return the greatest value in nums (or null if nums is empty)\n"
                "}"
            ),
        },
        test_cases=[
            {"input": "[3, 7, 2, 9, 4]", "expected_output": "9"},
            {"input": "[-5, -1, -12]", "expected_output": "-1"},
            {"input": "[]", "expected_output": "None"},
        ],
        entry_point={"python": "find_maximum", "typescript": "findMaximum"},
        judge_cases=[
            {"args": [[3, 7, 2, 9, 4]], "expected": 9},
            {"args": [[-5, -1, -12]], "expected": -1},
            {"args": [[]], "expected": None},
        ],
    ))

    db.add(Question(
        id="q_two_sum", title="Two Sum Encounter", difficulty="Medium",
        tags=["Arrays", "Hash Map"],
        prompt=(
            "Given an array of integers nums and an integer target, return indices of the "
            "two numbers such that they add up to target. Assume exactly one solution exists, "
            "and you may not use the same element twice."
        ),
        example_input="nums = [2, 7, 11, 15], target = 9", example_output="[0, 1]",
        starter_code={
            "python": "def two_sum(nums: list[int], target: int) -> list[int]:\n    # TODO: return the indices of the two numbers that add up to target\n    pass",
            "typescript": (
                "function twoSum(nums: number[], target: number): number[] {\n"
                "  // TODO: return the indices of the two numbers that add up to target\n"
                "}"
            ),
        },
        test_cases=[
            {"input": "nums = [2, 7, 11, 15], target = 9", "expected_output": "[0, 1]"},
            {"input": "nums = [3, 2, 4], target = 6", "expected_output": "[1, 2]"},
            {"input": "nums = [3, 3], target = 6", "expected_output": "[0, 1]"},
        ],
        entry_point={"python": "two_sum", "typescript": "twoSum"},
        judge_cases=[
            {"args": [[2, 7, 11, 15], 9], "expected": [0, 1]},
            {"args": [[3, 2, 4], 6], "expected": [1, 2]},
            {"args": [[3, 3], 6], "expected": [0, 1]},
        ],
    ))

    levels = [
        Level(id=1, world_id="w2", order=1, title="Syntax Verification", difficulty="easy",
              status="completed", stars=3, enemy_id="e_syntax_snake", xp_reward=80, gold_reward=30,
              question_id="q_find_max"),
        Level(id=2, world_id="w2", order=2, title="Array Basics & Traversal", difficulty="easy",
              status="completed", stars=3, enemy_id="e_bug_bot", xp_reward=90, gold_reward=35,
              question_id="q_find_max"),
        Level(id=3, world_id="w2", order=3, title="Find Maximum Element", difficulty="easy",
              status="completed", stars=3, enemy_id="e_array_beast", xp_reward=100, gold_reward=40,
              question_id="q_find_max"),
        Level(id=4, world_id="w2", order=4, title="Two Sum Encounter", difficulty="medium",
              status="current", stars=0, enemy_id="e_array_beast", xp_reward=250, gold_reward=100,
              question_id="q_two_sum"),
        Level(id=5, world_id="w2", order=5, title="Binary Search Protocol", difficulty="medium",
              status="locked", stars=0, enemy_id="e_string_samurai", xp_reward=220, gold_reward=90,
              question_id="q_two_sum"),
        Level(id=6, world_id="w2", order=6, title="Sliding Window Trap", difficulty="medium",
              status="locked", stars=0, enemy_id="e_string_samurai", xp_reward=230, gold_reward=95,
              question_id="q_two_sum"),
        Level(id=7, world_id="w2", order=7, title="Merge Intervals", difficulty="hard",
              status="locked", stars=0, enemy_id="e_recursion_zombie", xp_reward=350, gold_reward=150,
              question_id="q_two_sum"),
        Level(id=8, world_id="w2", order=8, title="Array Beast Overlord", difficulty="boss",
              status="locked", stars=0, enemy_id="e_algorithm_dragon", xp_reward=1500, gold_reward=500,
              question_id="q_two_sum"),
    ]
    for level in levels:
        db.add(level)

    enemies = [
        Enemy(id="e_array_beast", name="Array Beast", level=10, difficulty="medium", hp_max=1000,
              hp_current=720, vulnerability="Arrays / Hash Map", tier="minion", locked=False,
              unlock_hint="", xp_reward=250, gold_reward=100),
        Enemy(id="e_syntax_snake", name="Syntax Snake", level=4, difficulty="easy", hp_max=450,
              hp_current=450, vulnerability="Strings", tier="minion", locked=False,
              unlock_hint="", xp_reward=80, gold_reward=30),
        Enemy(id="e_bug_bot", name="Bug Bot", level=6, difficulty="easy", hp_max=600,
              hp_current=0, vulnerability="Loops", tier="minion", locked=False,
              unlock_hint="", xp_reward=60, gold_reward=25),
        Enemy(id="e_string_samurai", name="String Samurai", level=12, difficulty="medium", hp_max=1200,
              hp_current=1200, vulnerability="Two Pointers", tier="minion", locked=False,
              unlock_hint="", xp_reward=380, gold_reward=180),
        Enemy(id="e_recursion_zombie", name="Recursion Zombie", level=16, difficulty="hard", hp_max=2000,
              hp_current=2000, vulnerability="Stack Memory", tier="minion", locked=True,
              unlock_hint="Unlock: reach World 2 Boss", xp_reward=500, gold_reward=220),
        Enemy(id="e_algorithm_dragon", name="Algorithm Dragon", level=25, difficulty="boss", hp_max=5000,
              hp_current=5000, vulnerability="Dynamic Programming", tier="boss", locked=True,
              unlock_hint="Unlock: defeat 6 sector minions", xp_reward=1500, gold_reward=500),
    ]
    for enemy in enemies:
        db.add(enemy)

    db.commit()
