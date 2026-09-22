import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_state.dart';
import '../utils/theme.dart';
import 'hp_xp_bar.dart';
import 'stat_chip.dart';

/// Persistent player header used at the top of top-level screens: avatar,
/// name/level, HP + XP bars, gold and streak chips.
class AppHud extends StatelessWidget {
  const AppHud({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final player = state.player;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryContainer.withValues(alpha: 0.25),
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: const Icon(Icons.shield, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          player.displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            'LV.${player.level}',
                            style: AppTheme.mono(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.onPrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    HpXpBar(
                      progress: player.xpProgress,
                      color: AppColors.secondary,
                      trailing: '${player.xp}/${player.xpToNext} XP',
                      height: 6,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          HpXpBar(
            progress: player.hpProgress,
            color: AppColors.tertiary,
            label: 'HP',
            trailing: '${player.hp}/${player.hpMax}',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              StatChip(icon: Icons.monetization_on, label: '${player.gold}', color: AppColors.tertiary),
              const SizedBox(width: 8),
              StatChip(icon: Icons.local_fire_department, label: '${player.streak} day streak', color: AppColors.error),
            ],
          ),
        ],
      ),
    );
  }
}
