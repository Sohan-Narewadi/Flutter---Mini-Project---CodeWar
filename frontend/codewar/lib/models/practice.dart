import 'battle.dart';
import 'question.dart';

class TopicStat {
  const TopicStat({required this.id, required this.label, required this.solved, required this.masteryPercent});

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
  const PracticeStats({required this.streak, required this.solvedToday, required this.topics});

  final int streak;
  final int solvedToday;
  final List<TopicStat> topics;

  static const empty = PracticeStats(streak: 0, solvedToday: 0, topics: []);

  factory PracticeStats.fromJson(Map<String, dynamic> json) => PracticeStats(
        streak: json['streak'] ?? 0,
        solvedToday: json['solved_today'] ?? 0,
        topics: (json['topics'] as List? ?? [])
            .map((e) => TopicStat.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class PracticeSession {
  const PracticeSession({required this.practiceId, required this.daily, required this.question, this.topic = ''});

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
  });

  final BattleResult run; // passed/total/results/correctness
  final bool solved;
  final int xpEarned;
  final int goldEarned;
  final int streak;

  factory PracticeSubmitResult.fromJson(Map<String, dynamic> json) => PracticeSubmitResult(
        run: BattleResult.fromRunJson(json),
        solved: json['solved'] == true,
        xpEarned: json['xp_earned'] ?? 0,
        goldEarned: json['gold_earned'] ?? 0,
        streak: json['streak'] ?? 0,
      );
}

class Hint {
  const Hint({required this.level, required this.text});

  final int level;
  final String text;

  factory Hint.fromJson(Map<String, dynamic> json) =>
      Hint(level: json['level'] ?? 1, text: json['hint']?.toString() ?? '');
}
