class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.playerId,
    required this.name,
    required this.level,
    required this.rating,
    required this.value,
    required this.isMe,
  });

  final int rank;
  final int playerId;
  final String name;
  final int level;
  final int rating;
  final int value;
  final bool isMe;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) => LeaderboardEntry(
        rank: json['rank'] ?? 0,
        playerId: json['player_id'] ?? 0,
        name: json['name']?.toString() ?? '?',
        level: json['level'] ?? 1,
        rating: json['rating'] ?? 1000,
        value: json['value'] ?? 0,
        isMe: json['is_me'] == true,
      );
}

class Leaderboard {
  const Leaderboard({required this.scope, required this.metric, required this.entries, required this.me});

  final String scope;
  final String metric;
  final List<LeaderboardEntry> entries;
  final LeaderboardEntry me;

  /// True when the player's own row is not among [entries] (outside the top N).
  bool get meOutsideList => !entries.any((e) => e.isMe);

  factory Leaderboard.fromJson(Map<String, dynamic> json) => Leaderboard(
        scope: json['scope']?.toString() ?? 'global',
        metric: json['metric']?.toString() ?? 'xp',
        entries: (json['entries'] as List? ?? [])
            .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        me: LeaderboardEntry.fromJson(json['me'] as Map<String, dynamic>),
      );
}
