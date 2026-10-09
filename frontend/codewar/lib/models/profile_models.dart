import 'package:flutter/material.dart';

/// A badge from the server catalogue; [earnedAt] is null until really earned.
class BadgeInfo {
  const BadgeInfo({
    required this.key,
    required this.name,
    required this.description,
    required this.icon,
    this.earnedAt,
    this._earned,
  });

  final String key;
  final String name;
  final String description;
  final String icon;
  final DateTime? earnedAt;

  final bool? _earned;

  /// Earned for real. [earnedAt] can still be null for badges the server back-filled (real date unknown).
  bool get earned => _earned ?? earnedAt != null;

  IconData get iconData => _icons[icon] ?? Icons.workspace_premium_rounded;

  factory BadgeInfo.fromJson(Map<String, dynamic> j) => BadgeInfo(
    key: j['key']?.toString() ?? '',
    name: j['name']?.toString() ?? '',
    description: j['description']?.toString() ?? '',
    icon: j['icon']?.toString() ?? '',
    earnedAt: j['earned_at'] == null
        ? null
        : DateTime.tryParse(j['earned_at'].toString()),
    earned: j['earned'] is bool ? j['earned'] as bool : null,
  );

  static const _icons = <String, IconData>{
    'flag': Icons.flag_rounded,
    'local_fire_department': Icons.local_fire_department_rounded,
    'military_tech': Icons.military_tech_rounded,
    'whatshot': Icons.whatshot_rounded,
    'today': Icons.today_rounded,
    'school': Icons.school_rounded,
    'bolt': Icons.bolt_rounded,
    'date_range': Icons.date_range_rounded,
    'calendar_month': Icons.calendar_month_rounded,
    'emoji_events': Icons.emoji_events_rounded,
    'workspace_premium': Icons.workspace_premium_rounded,
    'stars': Icons.stars_rounded,
    'groups': Icons.groups_rounded,
    'trending_up': Icons.trending_up_rounded,
    'looks_5': Icons.looks_5_rounded,
    'filter_9_plus': Icons.filter_9_plus_rounded,
    'map': Icons.map_rounded,
  };
}

/// One finished online match for the signed-in player.
class MatchRecord {
  const MatchRecord({
    required this.roomCode,
    required this.mode,
    required this.rank,
    required this.playersCount,
    required this.bestPct,
    required this.ratingBefore,
    required this.ratingDelta,
    required this.xp,
    required this.gold,
    required this.opponents,
    required this.finishedAt,
  });

  final String roomCode;
  final String mode;
  final int rank;
  final int playersCount;
  final int bestPct;
  final int ratingBefore;
  final int ratingDelta;
  final int xp;
  final int gold;
  final List<String> opponents;
  final DateTime? finishedAt;

  bool get won => rank == 1 && playersCount > 1;

  factory MatchRecord.fromJson(Map<String, dynamic> j) => MatchRecord(
    roomCode: j['room_code']?.toString() ?? '',
    mode: j['mode']?.toString() ?? 'race',
    rank: j['rank'] ?? 0,
    playersCount: j['players_count'] ?? 1,
    bestPct: j['best_pct'] ?? 0,
    ratingBefore: j['rating_before'] ?? 1000,
    ratingDelta: j['rating_delta'] ?? 0,
    xp: j['xp'] ?? 0,
    gold: j['gold'] ?? 0,
    opponents: (j['opponents'] as List? ?? [])
        .map((e) => e.toString())
        .toList(),
    finishedAt: j['finished_at'] == null
        ? null
        : DateTime.tryParse(j['finished_at'].toString()),
  );
}

/// What anyone signed in can see about a player.
class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.name,
    required this.level,
    required this.rating,
    required this.tier,
    required this.wins,
    required this.losses,
    required this.totalXp,
    required this.badges,
  });

  final int id;
  final String name;
  final int level;
  final int rating;
  final String tier;
  final int wins;
  final int losses;
  final int totalXp;
  final List<String> badges;

  factory PublicProfile.fromJson(Map<String, dynamic> j) => PublicProfile(
    id: j['id'] ?? 0,
    name: j['name']?.toString() ?? '?',
    level: j['level'] ?? 1,
    rating: j['rating'] ?? 1000,
    tier: j['tier']?.toString() ?? 'bronze',
    wins: j['wins'] ?? 0,
    losses: j['losses'] ?? 0,
    totalXp: j['total_xp'] ?? 0,
    badges: (j['badges'] as List? ?? []).map((e) => e.toString()).toList(),
  );
}

/// "just now", "5m ago", "3h ago", "2d ago", else a short date.
String timeAgo(DateTime? t, {DateTime? now}) {
  if (t == null) return '';
  final d = (now ?? DateTime.now().toUtc()).difference(t.toUtc());
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}
