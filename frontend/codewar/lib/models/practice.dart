import 'battle.dart';
import 'profile_models.dart';
import 'question.dart';

class TopicStat {
  const TopicStat({
    required this.id,
    required this.label,
    required this.solved,
    required this.masteryPercent,
  });

  final String id;
  final String label;
  final int solved;
  final int masteryPercent;

  factory TopicStat.fromJson(Map<String, dynamic> json) => TopicStat(
    id: json['id']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
    solved: json['solved'] ?? 0,
    masteryPercent: json['mastery_percent'] ?? 0,
  );
}

class PracticeStats {
  const PracticeStats({
    required this.streak,
    required this.solvedToday,
    required this.topics,
    this.totalSolved = 0,
    this.dailyDone = false,
    this.dailyResetsIn = 0,
    this.fetchedAt,
  });

  final int streak;
  final int solvedToday;
  final List<TopicStat> topics;
  final int totalSolved;
  final bool dailyDone;

  /// Seconds until the daily challenge changes (0 when unknown).
  final int dailyResetsIn;

  /// When [dailyResetsIn] was measured, so the label keeps counting down.
  final DateTime? fetchedAt;

  static const empty = PracticeStats(streak: 0, solvedToday: 0, topics: []);

  /// "5h 12m" / "42m": human text for [dailyResetsIn], empty when unknown.
  String dailyLabel({DateTime? now}) {
    if (dailyResetsIn <= 0) return '';
    final elapsed = fetchedAt == null
        ? 0
        : (now ?? DateTime.now()).difference(fetchedAt!).inSeconds;
    final left = (dailyResetsIn - elapsed).clamp(60, 1 << 30);
    final h = left ~/ 3600;
    final m = (left % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m < 1 ? 1 : m}m';
  }

  /// Same as [dailyLabel] at the current time.
  String get dailyResetsLabel => dailyLabel();

  factory PracticeStats.fromJson(Map<String, dynamic> json) => PracticeStats(
    streak: json['streak'] ?? 0,
    solvedToday: json['solved_today'] ?? 0,
    totalSolved: json['total_solved'] ?? 0,
    dailyDone: json['daily_done'] == true,
    dailyResetsIn: json['daily_resets_in'] ?? 0,
    fetchedAt: DateTime.now(),
    topics: (json['topics'] as List? ?? [])
        .map((e) => TopicStat.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class PracticeSession {
  const PracticeSession({
    required this.practiceId,
    required this.daily,
    required this.question,
    this.topic = '',
  });

  final int practiceId;
  final bool daily;
  final Question question;
  final String topic;

  factory PracticeSession.fromJson(Map<String, dynamic> json) {
    final q = json['question'] as Map<String, dynamic>;
    return PracticeSession(
      practiceId: json['practice_id'] as int,
      daily: json['daily'] == true,
      question: Question.fromJson(q),
      topic: q['topic']?.toString() ?? '',
    );
  }
}

class PracticeSubmitResult {
  const PracticeSubmitResult({
    required this.run,
    required this.solved,
    required this.xpEarned,
    required this.goldEarned,
    required this.streak,
    this.newBadges = const [],
  });

  final BattleResult run; // passed/total/results/correctness
  final bool solved;
  final int xpEarned;
  final int goldEarned;
  final int streak;

  /// Badges unlocked by this very submission.
  final List<BadgeInfo> newBadges;

  factory PracticeSubmitResult.fromJson(Map<String, dynamic> json) =>
      PracticeSubmitResult(
        run: BattleResult.fromRunJson(json),
        solved: json['solved'] == true,
        xpEarned: json['xp_earned'] ?? 0,
        goldEarned: json['gold_earned'] ?? 0,
        streak: json['streak'] ?? 0,
        newBadges: (json['new_badges'] as List? ?? [])
            .map((e) => BadgeInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Hint {
  const Hint({required this.level, required this.text});

  final int level;
  final String text;

  factory Hint.fromJson(Map<String, dynamic> json) =>
      Hint(level: json['level'] ?? 1, text: json['hint']?.toString() ?? '');
}
