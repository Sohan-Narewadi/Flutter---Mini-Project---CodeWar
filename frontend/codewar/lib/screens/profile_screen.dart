import 'package:flutter/material.dart';
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
          const Text('Loadout', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
          const SizedBox(height: 10),
          _loadoutRow(Icons.gavel, 'Logic Blade Mk II', 'Primary Weapon · Equipped'),
          _loadoutRow(Icons.shield, 'Debug Shield', 'Defense · Locked'),
          _loadoutRow(Icons.smart_toy, 'Byte Bot v1.4', 'Support · Equipped'),
        ],
      ),
    );
  }

  Widget _loadoutRow(IconData icon, String name, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.onSurface)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
