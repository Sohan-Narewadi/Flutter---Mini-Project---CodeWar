import '../models/player.dart';
import '../models/world.dart';
import '../models/level_node.dart';
import '../models/enemy.dart';
import '../models/question.dart';

/// All offline seed data for the CodeWar demo. This guarantees the app
/// always has real, consistent data even with no backend reachable.
class SeedData {
  static const Player player = Player(
    id: 'p1',
    username: 'codeknight',
    displayName: 'CodeKnight',
    level: 12,
    xp: 600,
    xpToNext: 1000,
    hp: 800,
    hpMax: 1000,
    gold: 1240,
    streak: 7,
  );

  static const GameWorld world2 = GameWorld(
    id: 'w2',
    name: 'Array Ruins',
    order: 2,
    description: 'Sector 2 · Corrupted array structures roam these ruins.',
    clearedPercent: 0.5,
  );

  static final List<GameWorld> worlds = [world2];

  static final List<LevelNode> world2Nodes = [
    const LevelNode(
      id: 'n1',
      worldId: 'w2',
      order: 1,
      name: 'Syntax Verification',
      difficulty: Difficulty.easy,
      status: NodeStatus.done,
      stars: 3,
      enemyId: 'e_syntax_snake',
      xpReward: 80,
      goldReward: 30,
    ),
    const LevelNode(
      id: 'n2',
      worldId: 'w2',
      order: 2,
      name: 'Array Basics & Traversal',
      difficulty: Difficulty.easy,
      status: NodeStatus.done,
      stars: 3,
      enemyId: 'e_bug_bot',
      xpReward: 90,
      goldReward: 35,
    ),
    const LevelNode(
      id: 'n3',
      worldId: 'w2',
      order: 3,
      name: 'Find Maximum Element',
      difficulty: Difficulty.easy,
      status: NodeStatus.done,
      stars: 3,
      enemyId: 'e_array_beast',
      xpReward: 100,
      goldReward: 40,
    ),
    const LevelNode(
      id: 'n4',
      worldId: 'w2',
      order: 4,
      name: 'Two Sum Encounter',
      difficulty: Difficulty.medium,
      status: NodeStatus.current,
      stars: 0,
      enemyId: 'e_array_beast',
      xpReward: 250,
      goldReward: 100,
    ),
    const LevelNode(
      id: 'n5',
      worldId: 'w2',
      order: 5,
      name: 'Binary Search Protocol',
      difficulty: Difficulty.medium,
      status: NodeStatus.locked,
      stars: 0,
      enemyId: 'e_string_samurai',
      xpReward: 220,
      goldReward: 90,
    ),
    const LevelNode(
      id: 'n6',
      worldId: 'w2',
      order: 6,
      name: 'Sliding Window Trap',
      difficulty: Difficulty.medium,
      status: NodeStatus.locked,
      stars: 0,
      enemyId: 'e_string_samurai',
      xpReward: 230,
      goldReward: 95,
    ),
    const LevelNode(
      id: 'n7',
      worldId: 'w2',
      order: 7,
      name: 'Merge Intervals',
      difficulty: Difficulty.hard,
      status: NodeStatus.locked,
      stars: 0,
      enemyId: 'e_recursion_zombie',
      xpReward: 350,
      goldReward: 150,
    ),
    const LevelNode(
      id: 'n8',
      worldId: 'w2',
      order: 8,
      name: 'Array Beast Overlord',
      difficulty: Difficulty.boss,
      status: NodeStatus.locked,
      stars: 0,
      enemyId: 'e_algorithm_dragon',
      xpReward: 1500,
      goldReward: 500,
    ),
  ];

  static final List<Enemy> enemies = [
    const Enemy(
      id: 'e_array_beast',
      name: 'Array Beast',
      level: 10,
      difficulty: Difficulty.medium,
      hpMax: 1000,
      hpCurrent: 720,
      vulnerability: 'Arrays / Hash Map',
      tier: 'minion',
      locked: false,
      unlockHint: '',
      xpReward: 250,
      goldReward: 100,
      questionId: 'q_two_sum',
      engaged: true,
    ),
    const Enemy(
      id: 'e_syntax_snake',
      name: 'Syntax Snake',
      level: 4,
      difficulty: Difficulty.easy,
      hpMax: 450,
      hpCurrent: 450,
      vulnerability: 'Strings',
      tier: 'minion',
      locked: false,
      unlockHint: '',
      xpReward: 80,
      goldReward: 30,
      questionId: 'q_find_max',
    ),
    const Enemy(
      id: 'e_bug_bot',
      name: 'Bug Bot',
      level: 6,
      difficulty: Difficulty.easy,
      hpMax: 600,
      hpCurrent: 0,
      vulnerability: 'Loops',
      tier: 'minion',
      locked: false,
      unlockHint: '',
      xpReward: 60,
      goldReward: 25,
      questionId: 'q_find_max',
      defeated: true,
    ),
    const Enemy(
      id: 'e_string_samurai',
      name: 'String Samurai',
      level: 12,
      difficulty: Difficulty.medium,
      hpMax: 1200,
      hpCurrent: 1200,
      vulnerability: 'Two Pointers',
      tier: 'minion',
      locked: false,
      unlockHint: '',
      xpReward: 380,
      goldReward: 180,
      questionId: 'q_two_sum',
    ),
    const Enemy(
      id: 'e_recursion_zombie',
      name: 'Recursion Zombie',
      level: 16,
      difficulty: Difficulty.hard,
      hpMax: 2000,
      hpCurrent: 2000,
      vulnerability: 'Stack Memory',
      tier: 'minion',
      locked: true,
      unlockHint: 'Unlock: reach World 2 Boss',
      xpReward: 500,
      goldReward: 220,
      questionId: 'q_two_sum',
    ),
    const Enemy(
      id: 'e_algorithm_dragon',
      name: 'Algorithm Dragon',
      level: 25,
      difficulty: Difficulty.boss,
      hpMax: 5000,
      hpCurrent: 5000,
      vulnerability: 'Dynamic Programming',
      tier: 'boss',
      locked: true,
      unlockHint: 'Unlock: defeat 6 sector minions',
      xpReward: 1500,
      goldReward: 500,
      questionId: 'q_two_sum',
    ),
  ];

  static final Question findMaxQuestion = Question(
    id: 'q_find_max',
    title: 'Find Maximum Element',
    difficulty: 'Easy',
    tags: ['Arrays', 'Two Pointers'],
    prompt:
        'Given an integer array nums, return the greatest integer. Optimize for O(n) time and O(1) space.',
    exampleInput: 'nums = [3, 7, 2, 9, 4]',
    exampleOutput: '9',
    starterCode: {
      'python': '''def find_maximum(nums: list[int]) -> int:
    if not nums:
        return 0  # <- Bug: Return None
    max_val = nums[0]
    for n in nums:
        if n > max_val:
            max_val = n
    return max_val''',
      'typescript': '''function findMaximum(nums: number[]): number {
  if (nums.length === 0) {
    return 0; // <- Bug: Return None/null
  }
  let maxVal = nums[0];
  for (const n of nums) {
    if (n > maxVal) maxVal = n;
  }
  return maxVal;
}''',
      'cpp': '''int find_maximum(vector<int>& nums) {
    if (nums.empty()) {
        return 0; // <- Bug: should signal "no value"
    }
    int maxVal = nums[0];
    for (int n : nums) {
        if (n > maxVal) maxVal = n;
    }
    return maxVal;
}''',
    },
    testCases: const [
      TestCase(input: '[3, 7, 2, 9, 4]', expectedOutput: '9'),
      TestCase(input: '[-5, -1, -12]', expectedOutput: '-1'),
      TestCase(input: '[]', expectedOutput: 'None'),
    ],
  );

  static final Question twoSumQuestion = Question(
    id: 'q_two_sum',
    title: 'Two Sum Encounter',
    difficulty: 'Medium',
    tags: ['Arrays', 'Hash Map'],
    prompt:
        'Given an array of integers nums and an integer target, return indices of the two numbers such that they add up to target. Assume exactly one solution exists, and you may not use the same element twice.',
    exampleInput: 'nums = [2, 7, 11, 15], target = 9',
    exampleOutput: '[0, 1]',
    starterCode: {
      'python': '''def two_sum(nums: list[int], target: int) -> list[int]:
    pass''',
      'typescript': '''function twoSum(nums: number[], target: number): number[] {
  const seen = new Map<number, number>();
  for (let i = 0; i < nums.length; i++) {
    const complement = target - nums[i];
    if (seen.has(complement)) return [seen.get(complement)!, i];
    seen.set(nums[i], i);
  }
  return [];
}''',
      'cpp': '''vector<int> two_sum(vector<int>& nums, int target) {
    unordered_map<int, int> seen;
    for (int i = 0; i < nums.size(); i++) {
        int complement = target - nums[i];
        if (seen.count(complement)) return {seen[complement], i};
        seen[nums[i]] = i;
    }
    return {};
}''',
    },
    testCases: const [
      TestCase(input: 'nums = [2, 7, 11, 15], target = 9', expectedOutput: '[0, 1]'),
      TestCase(input: 'nums = [3, 2, 4], target = 6', expectedOutput: '[1, 2]'),
      TestCase(input: 'nums = [3, 3], target = 6', expectedOutput: '[0, 1]'),
    ],
  );

  static Question questionById(String id) {
    if (id == 'q_two_sum') return twoSumQuestion;
    return findMaxQuestion;
  }

  static Enemy enemyById(String id) {
    return enemies.firstWhere((e) => e.id == id, orElse: () => enemies.first);
  }
}
