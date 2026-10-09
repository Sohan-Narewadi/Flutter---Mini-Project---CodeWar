class Player {
  final String id;
  final String username;
  final String displayName;
  final int level;
  final int xp;
  final int xpToNext;
  final int hp;
  final int hpMax;
  final int gold;
  final int streak;
  final int rating;
  final int wins;
  final int losses;

  const Player({
    required this.id,
    required this.username,
    required this.displayName,
    required this.level,
    required this.xp,
    required this.xpToNext,
    required this.hp,
    required this.hpMax,
    required this.gold,
    required this.streak,
    this.rating = 1000,
    this.wins = 0,
    this.losses = 0,
  });

  double get xpProgress => xpToNext == 0 ? 0 : xp / xpToNext;
  double get hpProgress => hpMax == 0 ? 0 : hp / hpMax;

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id']?.toString() ?? 'p1',
      username: json['username'] ?? 'codeknight',
      displayName: json['display_name'] ?? 'CodeKnight',
      level: json['level'] ?? 1,
      xp: json['xp'] ?? 0,
      xpToNext: json['xp_to_next'] ?? 1000,
      hp: json['hp'] ?? 100,
      hpMax: json['hp_max'] ?? 100,
      gold: json['gold'] ?? 0,
      streak: json['streak'] ?? 0,
      rating: json['rating'] ?? 1000,
      wins: json['wins'] ?? 0,
      losses: json['losses'] ?? 0,
    );
  }

  Player copyWith({int? hp, int? gold, int? xp}) {
    return Player(
      id: id,
      username: username,
      displayName: displayName,
      level: level,
      xp: xp ?? this.xp,
      xpToNext: xpToNext,
      hp: hp ?? this.hp,
      hpMax: hpMax,
      gold: gold ?? this.gold,
      streak: streak,
      rating: rating,
      wins: wins,
      losses: losses,
    );
  }
}
