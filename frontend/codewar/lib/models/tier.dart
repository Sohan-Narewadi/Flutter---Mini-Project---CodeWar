import 'package:flutter/material.dart';

/// Rank tiers derived from the online rating. Thresholds mirror
/// `backend/app/tiers.py`; keep both in sync.
enum Tier {
  iron('iron', 'Iron', 0, Color(0xFF8B93A7)),
  bronze('bronze', 'Bronze', 900, Color(0xFFD9915B)),
  silver('silver', 'Silver', 1100, Color(0xFFC9D2E8)),
  gold('gold', 'Gold', 1300, Color(0xFFFFC24B)),
  platinum('platinum', 'Platinum', 1500, Color(0xFF4FE3D0)),
  diamond('diamond', 'Diamond', 1700, Color(0xFF9D8CFF));

  const Tier(this.key, this.label, this.minRating, this.color);

  final String key;
  final String label;
  final int minRating;
  final Color color;

  static Tier forRating(int rating) {
    var found = Tier.iron;
    for (final t in Tier.values) {
      if (rating >= t.minRating) found = t;
    }
    return found;
  }

  static Tier fromKey(String? key, {int rating = 1000}) {
    for (final t in Tier.values) {
      if (t.key == key) return t;
    }
    return forRating(rating);
  }

  /// The next tier up, or null at the top.
  Tier? get next =>
      index + 1 < Tier.values.length ? Tier.values[index + 1] : null;

  /// 0..1 progress from this tier's floor to the next tier's floor.
  double progress(int rating) {
    final n = next;
    if (n == null) return 1;
    return ((rating - minRating) / (n.minRating - minRating)).clamp(0.0, 1.0);
  }
}
