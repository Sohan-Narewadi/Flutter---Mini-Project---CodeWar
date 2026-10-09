class GameWorld {
  final String id;
  final String name;
  final int order;
  final String description;
  final double clearedPercent;

  const GameWorld({
    required this.id,
    required this.name,
    required this.order,
    required this.description,
    required this.clearedPercent,
  });

  static const placeholder = GameWorld(
    id: '',
    name: '',
    order: 0,
    description: '',
    clearedPercent: 0,
  );

  factory GameWorld.fromJson(Map<String, dynamic> json) {
    return GameWorld(
      id: json['id']?.toString() ?? 'w1',
      name: json['name'] ?? 'Array Ruins',
      order: json['order'] ?? 1,
      description: json['description'] ?? '',
      // Backend sends cleared_percent as an integer 0-100; this model stores
      // it as a 0.0-1.0 fraction (consumed directly by LinearProgressIndicator).
      clearedPercent:
          ((json['cleared_percent'] ?? 0) as num).toDouble() / 100.0,
    );
  }
}
