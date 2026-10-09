import 'package:flutter/material.dart';

import '../models/tier.dart';
import '../utils/theme.dart';

/// Player avatar: the first letter on a dark disc with a ring in the player's
/// tier colour (no uploaded images, so nothing to fake).
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.name,
    this.tier,
    this.size = 44,
    this.glow = false,
  });

  final String name;
  final Tier? tier;
  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final color = tier?.color ?? AppColors.accent;
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceHigh,
        border: Border.all(color: color, width: size >= 64 ? 3 : 2),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: size / 2,
                ),
              ]
            : null,
      ),
      child: Text(
        initial,
        style: AppTheme.display(fontSize: size * 0.42, color: color),
      ),
    );
  }
}

/// Small pill with the tier name in the tier colour.
class TierBadge extends StatelessWidget {
  const TierBadge({super.key, required this.tier, this.compact = false});

  final Tier tier;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: tier.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: tier.color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.diamond_rounded,
            size: compact ? 11 : 13,
            color: tier.color,
          ),
          const SizedBox(width: 4),
          Text(
            tier.label.toUpperCase(),
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: tier.color,
            ),
          ),
        ],
      ),
    );
  }
}
