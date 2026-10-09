import 'question.dart';

class TestResult {
  final String input;
  final String expected;
  final String actual;
  final bool passed;
  final num durationMs;

  const TestResult({
    required this.input,
    required this.expected,
    required this.actual,
    required this.passed,
    required this.durationMs,
  });

  factory TestResult.fromJson(Map<String, dynamic> json) {
    return TestResult(
      input: json['input']?.toString() ?? '',
      expected: json['expected']?.toString() ?? '',
      actual: json['actual']?.toString() ?? '',
      passed: json['passed'] == true,
      durationMs: (json['duration_ms'] as num?) ?? 0,
    );
  }
}

/// A single /run or /submit response from the backend. `won` reflects
/// `outcome == "won"`; a partial-credit submit that leaves the battle
/// in progress has `outcome == "in_progress"` and `won == false` - callers
/// must check `finalized` before navigating to a victory/defeat screen.
class BattleResult {
  final int passedTests;
  final int totalTests;
  final List<TestResult> results;
  final String outcome; // "in_progress" | "won" | "lost" | "expired"
  final int xpEarned;
  final int goldEarned;
  final int hpLost;
  final int correctnessPercent;
  final int damageDealt;
  final int enemyHpRemaining;
  final int enemyHpMax;
  final bool enemyDefeated;
  final bool isNewBest;
  final int bestScorePercent;

  const BattleResult({
    required this.passedTests,
    required this.totalTests,
    required this.results,
    required this.outcome,
    required this.xpEarned,
    required this.goldEarned,
    required this.hpLost,
    this.correctnessPercent = 0,
    this.damageDealt = 0,
    this.enemyHpRemaining = 0,
    this.enemyHpMax = 0,
    this.enemyDefeated = false,
    this.isNewBest = false,
    this.bestScorePercent = 0,
  });

  bool get won => outcome == 'won';

  /// True once the battle is done and the client should navigate away from
  /// the IDE (victory/defeat/expired) rather than staying in "in_progress".
  bool get finalized => outcome != 'in_progress';

  factory BattleResult.fromRunJson(Map<String, dynamic> json) {
    final results = (json['results'] as List? ?? [])
        .map((e) => TestResult.fromJson(e as Map<String, dynamic>))
        .toList();
    return BattleResult(
      passedTests: json['passed_tests'] ?? 0,
      totalTests: json['total_tests'] ?? 0,
      results: results,
      outcome: 'in_progress',
      xpEarned: 0,
      goldEarned: 0,
      hpLost: 0,
      correctnessPercent: json['correctness_percent'] ?? 0,
    );
  }

  factory BattleResult.fromSubmitJson(Map<String, dynamic> json) {
    final results = (json['results'] as List? ?? [])
        .map((e) => TestResult.fromJson(e as Map<String, dynamic>))
        .toList();
    return BattleResult(
      passedTests: json['passed_tests'] ?? 0,
      totalTests: json['total_tests'] ?? 0,
      results: results,
      outcome: json['outcome']?.toString() ?? 'in_progress',
      xpEarned: json['xp_earned'] ?? 0,
      goldEarned: json['gold_earned'] ?? 0,
      hpLost: json['hp_lost'] ?? 0,
      correctnessPercent: json['correctness_percent'] ?? 0,
      damageDealt: json['damage_dealt'] ?? 0,
      enemyHpRemaining: json['enemy_hp_remaining'] ?? 0,
      enemyHpMax: json['enemy_hp_max'] ?? 0,
      enemyDefeated: json['enemy_defeated'] == true,
      isNewBest: json['is_new_best'] == true,
      bestScorePercent: json['best_score_percent'] ?? 0,
    );
  }
}

/// Server response to POST /api/battles/start.
class BattleStartResult {
  final int battleId;
  final int enemyHpRemaining;
  final int timeLimitS;
  final String? startedAt;
  final Question question;

  const BattleStartResult({
    required this.battleId,
    required this.enemyHpRemaining,
    required this.timeLimitS,
    required this.question,
    this.startedAt,
  });

  factory BattleStartResult.fromJson(Map<String, dynamic> json) {
    return BattleStartResult(
      battleId: json['battle_id'] is int
          ? json['battle_id'] as int
          : int.parse('${json['battle_id']}'),
      enemyHpRemaining: json['enemy_hp_remaining'] ?? 0,
      timeLimitS: json['time_limit_s'] ?? 300,
      startedAt: json['started_at']?.toString(),
      // The backend resolves the question via the Level (Level.question_id),
      // not the Enemy - this is the canonical source, not a fallback lookup
      // keyed on Enemy.questionId (which the backend doesn't even send).
      question: Question.fromJson(json['question'] as Map<String, dynamic>),
    );
  }
}

/// Thrown by battle-submission API calls (start/run/submit) on any failure -
/// network error, timeout, or non-2xx response. Unlike the read-only GET
/// methods on ApiService, these must NEVER silently fall back to fake local
/// results, since a real battle submission requires the backend.
class BattleApiException implements Exception {
  BattleApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
