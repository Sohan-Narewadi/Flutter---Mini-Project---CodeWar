import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/battle.dart';
import '../providers/game_state.dart';
import '../services/sfx.dart';
import '../ui/app_card.dart';
import '../ui/app_scaffold.dart';
import '../ui/neon_button.dart';
import '../ui/stat_tile.dart';
import '../utils/theme.dart';
import '../widgets/no_result_redirect.dart';

/// Shown after the server confirms the enemy is defeated. Every number comes
/// from the final submission's response.
class BattleVictoryScreen extends StatefulWidget {
  const BattleVictoryScreen({super.key});

  @override
  State<BattleVictoryScreen> createState() => _BattleVictoryScreenState();
}

class _BattleVictoryScreenState extends State<BattleVictoryScreen> {
  late final BattleResult? _result = context.read<GameState>().lastResult;

  @override
  void initState() {
    super.initState();
    Sfx.play(Cue.win);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final result = _result;
    if (result == null) return const NoResultRedirect();
    final enemy = state.currentEnemy;
    final level = state.currentLevel;

    return AppScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpace.page, 32, AppSpace.page, 24),
        children: [
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1),
              duration: const Duration(milliseconds: 520),
              curve: Curves.elasticOut,
              builder: (context, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.14),
                  border: Border.all(color: AppColors.gold, width: 3),
                  boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.5), blurRadius: 40)],
                ),
                child: const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 54),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Center(child: Text('VICTORY', style: AppTheme.display(fontSize: 38, letterSpacing: 6, color: AppColors.gold))),
          const SizedBox(height: 6),
          Center(
            child: Text(
              '${enemy?.name ?? 'Enemy'} defeated${level == null ? '' : '  ·  Level ${level.order} cleared'}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textDim, fontSize: 14),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(child: StatTile(icon: Icons.bolt_rounded, color: AppColors.accent, value: '+${result.xpEarned}', label: 'XP')),
              const SizedBox(width: 10),
              Expanded(child: StatTile(icon: Icons.monetization_on_rounded, color: AppColors.gold, value: '+${result.goldEarned}', label: 'Gold')),
            ],
          ),
          const SizedBox(height: 10),
          AppCard(
            child: Row(
              children: [
                Expanded(child: _Stat(label: 'Accuracy', value: '${result.correctnessPercent}%')),
                Expanded(child: _Stat(label: 'Tests', value: '${result.passedTests}/${result.totalTests}')),
                Expanded(child: _Stat(label: 'Final hit', value: '${result.damageDealt}')),
              ],
            ),
          ),
          const SizedBox(height: 28),
          NeonButton(key: const Key('victoryContinue'), label: 'Continue', icon: Icons.arrow_forward_rounded, onPressed: () => context.go('/home')),
          const SizedBox(height: 10),
          NeonButton(label: 'Back to Arena', variant: NeonVariant.secondary, onPressed: () => context.go('/battle')),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTheme.display(fontSize: 20)),
        const SizedBox(height: 2),
        Text(label.toUpperCase(), style: AppTheme.overline()),
      ],
    );
  }
}
