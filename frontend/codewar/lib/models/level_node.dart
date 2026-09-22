enum NodeStatus { done, current, locked }

enum Difficulty { easy, medium, hard, boss }

Difficulty difficultyFromString(String? s) {
  switch ((s ?? 'easy').toLowerCase()) {
    case 'medium':
      return Difficulty.medium;
    case 'hard':
      return Difficulty.hard;
    case 'boss':
      return Difficulty.boss;
    default:
      return Difficulty.easy;
  }
}

String difficultyLabel(Difficulty d) {
  switch (d) {
    case Difficulty.easy:
      return 'Easy';
    case Difficulty.medium:
      return 'Medium';
    case Difficulty.hard:
      return 'Hard';
    case Difficulty.boss:
      return 'Boss';
  }
}

class LevelNode {
  final String id;
  final String worldId;
  final int order;
  final String name;
  final Difficulty difficulty;
  final NodeStatus status;
  final int stars;
  final String enemyId;
  final int xpReward;
  final int goldReward;

  const LevelNode({
    required this.id,
    required this.worldId,
    required this.order,
    required this.name,
    required this.difficulty,
    required this.status,
    required this.stars,
    required this.enemyId,
    required this.xpReward,
    required this.goldReward,
  });

  factory LevelNode.fromJson(Map<String, dynamic> json) {
    NodeStatus status;
    // Backend Level.status values are "completed" / "current" / "locked"
    // (see backend/app/models/level.py); "done" was this model's original
    // (seed-only) naming and is kept as an accepted alias.
    switch ((json['status'] ?? 'locked').toString()) {
      case 'done':
      case 'completed':
        status = NodeStatus.done;
        break;
      case 'current':
        status = NodeStatus.current;
        break;
      default:
        status = NodeStatus.locked;
    }
    return LevelNode(
      id: json['id']?.toString() ?? '',
      worldId: json['world_id']?.toString() ?? '',
      order: json['order'] ?? 0,
      // Backend's LevelOut schema field is "title", not "name".
      name: json['title'] ?? json['name'] ?? '',
      difficulty: difficultyFromString(json['difficulty']),
      status: status,
      stars: json['stars'] ?? 0,
      enemyId: json['enemy_id']?.toString() ?? '',
      xpReward: json['xp_reward'] ?? 0,
      goldReward: json['gold_reward'] ?? 0,
    );
  }
}
