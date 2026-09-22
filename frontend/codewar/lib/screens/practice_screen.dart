import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/game_state.dart';
import '../utils/theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/enemy_card.dart';

/// Practice: the enemy list filtered to farmable easy encounters, good for
/// drilling without risking a real sector attempt.
class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final drills = state.farmableEnemies;

    return AppShell(
      title: 'Practice',
      navIndex: 2,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Practice Drills', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
          const SizedBox(height: 6),
          const Text(
            'Farmable Easy encounters — low risk, good for warming up before a sector push.',
            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (drills.isEmpty)
            const Text('No practice drills unlocked yet.', style: TextStyle(color: AppColors.onSurfaceVariant))
          else
            for (final enemy in drills)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: EnemyCard(
                  enemy: enemy,
                  onFight: () => context.push('/prepare/${enemy.id}'),
                ),
              ),
        ],
      ),
    );
  }
}
