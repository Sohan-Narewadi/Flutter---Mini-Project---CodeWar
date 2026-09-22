import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/game_state.dart';
import '../utils/theme.dart';
import '../widgets/reward_row.dart';

class BattleVictoryScreen extends StatelessWidget {
  const BattleVictoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final result = state.lastResult;
    final enemy = state.currentEnemy;
    final level = state.currentLevel;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(color: AppColors.secondary),
                ),
                child: Text(
                  'VICTORY · ${result?.passedTests ?? 3}/${result?.totalTests ?? 3} TESTS PASSED',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.secondary),
                ),
              ),
              const SizedBox(height: 20),
              const Icon(Icons.emoji_events, color: AppColors.tertiary, size: 72),
              const SizedBox(height: 12),
              const Text('Battle Won', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.onSurface)),
              const SizedBox(height: 6),
              Text(
                '${enemy?.name ?? "Array Beast"} (Lvl ${enemy?.level ?? 10}) · Sector ${level?.order.toString().padLeft(2, '0') ?? "04"} Cleared',
                style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _telemetry('Accuracy', '${result?.correctnessPercent ?? 100}%', 'solution', AppColors.secondary)),
                        Expanded(child: _telemetry('Damage Dealt', '${result?.damageDealt ?? enemy?.hpMax ?? 0}', 'this hit', AppColors.tertiary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _telemetry('Coverage', '${result?.passedTests ?? 3}/${result?.totalTests ?? 3}', 'tests', AppColors.primary)),
                        Expanded(child: _telemetry('Best Score', '${result?.bestScorePercent ?? 100}%', 'this battle', AppColors.secondary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Rewards', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
              ),
              const SizedBox(height: 10),
              RewardRow(icon: Icons.bolt, label: 'Experience', value: '+${result?.xpEarned ?? enemy?.xpReward ?? 250} XP', color: AppColors.secondary),
              RewardRow(icon: Icons.monetization_on, label: 'Coins', value: '+${result?.goldEarned ?? enemy?.goldReward ?? 100}', color: AppColors.tertiary),
              const RewardRow(icon: Icons.auto_awesome, label: 'Skill Point', value: '+1', color: AppColors.primary),
              const RewardRow(icon: Icons.diamond, label: 'Corrupted Byte Shard (Tier 2)', value: 'x1', color: AppColors.primary),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Next Battle (Sector 05)'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go('/battle'),
                  child: const Text('Return to Arena'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _telemetry(String label, String value, String sub, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: AppTheme.mono(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          if (sub.isNotEmpty) Text(sub, style: AppTheme.mono(fontSize: 10, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}
