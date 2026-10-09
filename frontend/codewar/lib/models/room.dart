/// Mirrors the room snapshot documented in docs/superpowers/rooms-protocol.md.
class RoomPlayer {
  const RoomPlayer({
    required this.playerId,
    required this.name,
    required this.connected,
    required this.isHost,
    required this.passed,
    required this.total,
    required this.bestPct,
    required this.submissions,
    required this.forfeited,
    this.rank,
  });

  final int playerId;
  final String name;
  final bool connected;
  final bool isHost;
  final int passed;
  final int total;
  final int bestPct;
  final int submissions;
  final bool forfeited;
  final int? rank;

  factory RoomPlayer.fromJson(Map<String, dynamic> j) => RoomPlayer(
    playerId: j['player_id'] ?? 0,
    name: j['name']?.toString() ?? '?',
    connected: j['connected'] == true,
    isHost: j['is_host'] == true,
    passed: j['passed'] ?? 0,
    total: j['total'] ?? 0,
    bestPct: j['best_pct'] ?? 0,
    submissions: j['submissions'] ?? 0,
    forfeited: j['forfeited'] == true,
    rank: j['rank'] as int?,
  );
}

class Standing {
  const Standing({
    required this.playerId,
    required this.name,
    required this.rank,
    required this.bestPct,
    required this.forfeited,
    this.timeS,
    this.ratingDelta,
    this.xp,
    this.gold,
    this.rating,
  });

  final int playerId;
  final String name;
  final int rank;
  final int bestPct;
  final bool forfeited;
  final num? timeS;
  final int? ratingDelta;
  final int? xp;
  final int? gold;
  final int? rating;

  bool get hasRewards => ratingDelta != null;

  factory Standing.fromJson(Map<String, dynamic> j) => Standing(
    playerId: j['player_id'] ?? 0,
    name: j['name']?.toString() ?? '?',
    rank: j['rank'] ?? 0,
    bestPct: j['best_pct'] ?? 0,
    forfeited: j['forfeited'] == true,
    timeS: j['time_s'] as num?,
    ratingDelta: j['rating_delta'] as int?,
    xp: j['xp'] as int?,
    gold: j['gold'] as int?,
    rating: j['rating'] as int?,
  );
}

class RoomSnapshot {
  const RoomSnapshot({
    required this.code,
    required this.mode,
    required this.difficulty,
    required this.language,
    required this.status,
    required this.hostId,
    required this.maxPlayers,
    required this.timeLimitS,
    required this.players,
    this.secondsLeft,
    this.countdownLeft,
    this.reason,
    this.preparing = false,
    this.standings,
  });

  final String code;
  final String mode; // race | duel
  final String difficulty;
  final String language;
  final String status; // lobby | countdown | running | finished
  final int hostId;
  final int maxPlayers;
  final int timeLimitS;
  final int? secondsLeft;
  final double? countdownLeft;
  final String? reason;
  final bool preparing;
  final List<RoomPlayer> players;
  final List<Standing>? standings;

  bool get isDuel => mode == 'duel';

  RoomPlayer? playerById(int id) {
    for (final p in players) {
      if (p.playerId == id) return p;
    }
    return null;
  }

  factory RoomSnapshot.fromJson(Map<String, dynamic> j) => RoomSnapshot(
    code: j['code']?.toString() ?? '',
    mode: j['mode']?.toString() ?? 'race',
    difficulty: j['difficulty']?.toString() ?? 'easy',
    language: j['language']?.toString() ?? 'python',
    status: j['status']?.toString() ?? 'lobby',
    hostId: j['host_id'] ?? 0,
    maxPlayers: j['max_players'] ?? 8,
    timeLimitS: j['time_limit_s'] ?? 300,
    secondsLeft: j['seconds_left'] as int?,
    countdownLeft: (j['countdown_left'] as num?)?.toDouble(),
    reason: j['reason']?.toString(),
    preparing: j['preparing'] == true,
    players: (j['players'] as List? ?? [])
        .map((e) => RoomPlayer.fromJson(e as Map<String, dynamic>))
        .toList(),
    standings: (j['standings'] as List?)
        ?.map((e) => Standing.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
