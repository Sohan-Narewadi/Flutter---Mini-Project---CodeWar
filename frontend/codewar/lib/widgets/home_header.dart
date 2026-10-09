import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/game_state.dart';
import '../ui/skeleton.dart';
import '../utils/format.dart';
import '../utils/theme.dart';

/// Compact player header for the Home tab only: avatar with an XP ring, name,
/// level, gold and streak in a single ~64px row. Other tabs show the player in
/// Profile instead of repeating this.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final player = state.player;

    if (!state.hasLoaded) {
      return const Padding(
        key: Key('hudSkeleton'),
        padding: EdgeInsets.fromLTRB(AppSpace.page, 16, AppSpace.page, 8),
        child: Row(
          children: [
            SkeletonBox(height: 52, width: 52, radius: 26),
            SizedBox(width: 12),
            Expanded(child: SkeletonBox(height: 32)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 16, AppSpace.page, 8),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Open profile',
            child: GestureDetector(
              key: const Key('homeAvatar'),
              onTap: () => context.go('/profile'),
              child: SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: CircularProgressIndicator(
                        value: player.xpProgress.clamp(0.0, 1.0),
                        strokeWidth: 3,
                        backgroundColor: AppColors.line,
                        color: AppColors.accent,
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceHigh,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        player.displayName.isEmpty
                            ? '?'
                            : player.displayName.characters.first.toUpperCase(),
                        style: AppTheme.display(
                          fontSize: 18,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.display(fontSize: 18),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'LEVEL ${player.level}  ·  ${player.xp}/${player.xpToNext} XP',
                    maxLines: 1,
                    style: AppTheme.overline(color: AppColors.textDim),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Pill(
            icon: Icons.monetization_on_rounded,
            value: compactNumber(player.gold),
            color: AppColors.gold,
            tooltip: 'Gold',
          ),
          const SizedBox(width: 8),
          _Pill(
            icon: Icons.local_fire_department_rounded,
            value: '${player.streak}',
            color: player.streak > 0 ? AppColors.danger : AppColors.textFaint,
            tooltip: 'Day streak',
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.value,
    required this.color,
    required this.tooltip,
  });
  final IconData icon;
  final String value;
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              textScaler: TextScaler.noScaling,
              style: AppTheme.display(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
