import 'level_node.dart';

class Enemy {
  final String id;
  final String name;
  final int level;
  final Difficulty difficulty;
  final int hpMax;
  final int hpCurrent;
  final String vulnerability;
  final String tier;
  final bool locked;
  final String unlockHint;
  final int xpReward;
  final int goldReward;
  final String questionId;
  final bool engaged;
  final bool defeated;

  const Enemy({
    required this.id,
    required this.name,
    required this.level,
    required this.difficulty,
    required this.hpMax,
    required this.hpCurrent,
    required this.vulnerability,
    required this.tier,
    required this.locked,
    required this.unlockHint,
    required this.xpReward,
    required this.goldReward,
    required this.questionId,
    this.engaged = false,
    this.defeated = false,
  });

  double get hpProgress => hpMax == 0 ? 0 : hpCurrent / hpMax;

  factory Enemy.fromJson(Map<String, dynamic> json) {
    return Enemy(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      level: json['level'] ?? 1,
      difficulty: difficultyFromString(json['difficulty']),
      hpMax: json['hp_max'] ?? 100,
      hpCurrent: json['hp_current'] ?? json['hp_max'] ?? 100,
      vulnerability: json['vulnerability'] ?? '',
      // Backend sends "minion" / "boss" (see backend/app/models/enemy.py);
      // this was previously typed as int, which threw a TypeError on every
      // parse and made fetchEnemies() silently fall back to seed data -
      // masking itself as "backend connectivity issue" when the real
      // problem was a model/schema type mismatch.
      tier: json['tier']?.toString() ?? 'minion',
      locked: json['locked'] ?? false,
      unlockHint: json['unlock_hint'] ?? '',
      xpReward: json['xp_reward'] ?? 0,
      goldReward: json['gold_reward'] ?? 0,
      questionId: json['question_id']?.toString() ?? '',
    );
  }
}
