import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/game_state.dart';
import '../utils/theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/hp_xp_bar.dart';
import '../widgets/stat_chip.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final player = state.player;
    final defeatedCount = state.enemies.where((e) => e.defeated).length;

    return AppShell(
      title: 'Profile',
      navIndex: 4,
      showHud: false,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryContainer.withValues(alpha: 0.25),
                border: Border.all(color: AppColors.primary, width: 3),
              ),
              child: const Icon(Icons.shield, color: AppColors.primary, size: 40),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(player.displayName,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
          ),
          Center(
            child: Text('@${player.username} · Level ${player.level}',
                style: AppTheme.mono(fontSize: 12, color: AppColors.onSurfaceVariant)),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Column(
              children: [
                HpXpBar(progress: player.hpProgress, color: AppColors.tertiary, label: 'HP', trailing: '${player.hp}/${player.hpMax}'),
                const SizedBox(height: 12),
                HpXpBar(progress: player.xpProgress, color: AppColors.secondary, label: 'XP', trailing: '${player.xp}/${player.xpToNext}'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatChip(icon: Icons.monetization_on, label: '${player.gold} Gold', color: AppColors.tertiary),
              StatChip(icon: Icons.local_fire_department, label: '${player.streak} day streak', color: AppColors.error),
              StatChip(icon: Icons.pets, label: '$defeatedCount enemies defeated', color: AppColors.secondary),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Online record', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _recordTile('Rating', '${player.rating}', AppColors.primary)),
              const SizedBox(width: 10),
              Expanded(child: _recordTile('Wins', '${player.wins}', AppColors.secondary)),
              const SizedBox(width: 10),
              Expanded(child: _recordTile('Losses', '${player.losses}', AppColors.error)),
            ],
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('Settings & server'),
          ),
        ],
      ),
    );
  }

  Widget _recordTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          Text(value, style: AppTheme.mono(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}
