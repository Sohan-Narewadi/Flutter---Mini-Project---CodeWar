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
import '../widgets/hp_xp_bar.dart';
import '../widgets/no_result_redirect.dart';

/// Shown when the server ends the battle as lost (HP reached 0) or expired.
/// It only reports what actually happened: the outcome, the real numbers and
/// the first failing test (if the judge returned one).
class BattleDefeatScreen extends StatefulWidget {
  const BattleDefeatScreen({super.key});

  @override
  State<BattleDefeatScreen> createState() => _BattleDefeatScreenState();
}

class _BattleDefeatScreenState extends State<BattleDefeatScreen> {
  bool _retrying = false;

  /// The result this screen was opened with. Starting a retry clears
  /// `GameState.lastResult`; holding our own copy stops that rebuild from
  /// bouncing the player home before the new battle opens.
  late final BattleResult? _result = context.read<GameState>().lastResult;

  @override
  void initState() {
    super.initState();
    Sfx.play(Cue.lose);
  }

  Future<void> _retry(GameState state) async {
    setState(() => _retrying = true);
    try {
      await state.startBattle(
        enemy: state.currentEnemy,
        level: state.currentLevel,
      );
      if (!mounted) return;
      context.pushReplacement('/ide');
    } on BattleApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final result = _result;
    if (result == null) return const NoResultRedirect();
    final enemy = state.currentEnemy;
    final player = state.player;
    final failed = result.results.where((r) => !r.passed).firstOrNull;
    final expired = result.outcome == 'expired';
    final enemyDamagePct = state.enemyHpMax == 0
        ? 0
        : (100 * (state.enemyHpMax - state.enemyHpRemaining) / state.enemyHpMax)
              .round();

    return AppScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.page,
          32,
          AppSpace.page,
          24,
        ),
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.danger.withValues(alpha: 0.12),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.8),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.danger.withValues(alpha: 0.35),
                    blurRadius: 36,
                  ),
                ],
              ),
              child: Icon(
                expired ? Icons.timer_off_rounded : Icons.heart_broken_rounded,
                color: AppColors.danger,
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'DEFEAT',
              style: AppTheme.display(
                fontSize: 36,
                letterSpacing: 6,
                color: AppColors.danger,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              expired
                  ? "Time ran out against ${enemy?.name ?? 'the enemy'}."
                  : '${enemy?.name ?? 'The enemy'} wore you down.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textDim, fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.rule_rounded,
                  color: AppColors.accent,
                  value: '${result.passedTests}/${result.totalTests}',
                  label: 'Tests passed',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  icon: Icons.flash_on_rounded,
                  color: AppColors.gold,
                  value: '$enemyDamagePct%',
                  label: 'Enemy damaged',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppCard(
            child: HpXpBar(
              progress: player.hpProgress,
              color: AppColors.accent,
              label: 'YOUR HP',
              trailing: '${player.hp}/${player.hpMax}',
              height: 8,
            ),
          ),
          if (failed != null) ...[
            const SizedBox(height: 14),
            AppCard(
              accent: AppColors.danger,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FIRST FAILING TEST',
                    style: AppTheme.overline(color: AppColors.danger),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Input    ${failed.input}',
                    style: AppTheme.mono(
                      fontSize: 12.5,
                      color: AppColors.textDim,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Expected ${failed.expected}',
                    style: AppTheme.mono(
                      fontSize: 12.5,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Got      ${failed.actual}',
                    style: AppTheme.mono(
                      fontSize: 12.5,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: AppColors.textFaint,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'HP slowly regenerates over time. Practice mode never costs HP, so it is a safe place to sharpen up before you try again.',
                  style: TextStyle(
                    color: AppColors.textFaint,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          NeonButton(
            key: const Key('retryBattle'),
            label: 'Try again',
            icon: Icons.replay_rounded,
            loading: _retrying,
            onPressed: _retrying ? null : () => _retry(state),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: NeonButton(
                  label: 'Practice',
                  variant: NeonVariant.secondary,
                  onPressed: () => context.go('/practice'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NeonButton(
                  label: 'Home',
                  variant: NeonVariant.secondary,
                  onPressed: () => context.go('/home'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
