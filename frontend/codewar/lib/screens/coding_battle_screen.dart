import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/battle.dart';
import '../providers/game_state.dart';
import '../utils/theme.dart';
import '../ui/shake.dart';
import '../widgets/code_editor_panel.dart';
import '../widgets/hp_xp_bar.dart';
import '../widgets/test_case_tile.dart';

/// Coding Battle IDE: live timer, dual HP gauges, challenge spec, code
/// editor, test runner panel, and the Run Tests / Submit Attack actions.
class CodingBattleScreen extends StatefulWidget {
  const CodingBattleScreen({super.key});

  @override
  State<CodingBattleScreen> createState() => _CodingBattleScreenState();
}

class _CodingBattleScreenState extends State<CodingBattleScreen> {
  Timer? _timer;
  int _secondsLeft = 0;
  bool _timerSeeded = false;
  BattleResult? _lastRun;
  bool _specExpanded = true;
  bool _isRunning = false;
  bool _isSubmitting = false;

  void _seedTimerIfNeeded(GameState state) {
    if (_timerSeeded) return;
    _timerSeeded = true;
    // Recompute remaining time from the battle's actual server-reported
    // start time rather than always resetting to a fresh full countdown -
    // if the user left and returned to an in-progress battle, the clock
    // should reflect real elapsed time, not pretend a full window remains.
    final startedAt = state.battleStartedAt;
    final elapsed = startedAt != null ? DateTime.now().difference(startedAt).inSeconds : 0;
    _secondsLeft = (state.timeLimitS - elapsed).clamp(0, state.timeLimitS);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) _secondsLeft--;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _clock {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get _timeUp => _secondsLeft <= 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final question = state.currentQuestion;
    final enemy = state.currentEnemy;
    final player = state.player;

    if (question == null || enemy == null || state.battleId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Coding Battle')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No active battle.', style: TextStyle(color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => context.go('/battle'),
                child: const Text('Back to Battle Arena'),
              ),
            ],
          ),
        ),
      );
    }

    _seedTimerIfNeeded(state);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer, size: 18, color: AppColors.tertiary),
            const SizedBox(width: 6),
            Text(_clock, style: AppTheme.mono(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.tertiary)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Dual HP gauges
                  Row(
                    children: [
                      Expanded(
                        child: HpXpBar(
                          progress: player.hpProgress,
                          color: AppColors.secondary,
                          label: 'YOU',
                          trailing: '${player.hp}/${player.hpMax}',
                          height: 6,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ShakeOnDecrease(
                          trigger: state.enemyHpRemaining,
                          child: HpXpBar(
                            progress: state.enemyHpMax == 0 ? 0 : state.enemyHpRemaining / state.enemyHpMax,
                            color: AppColors.error,
                            label: enemy.name.toUpperCase(),
                            trailing: '${state.enemyHpRemaining}/${state.enemyHpMax}',
                            height: 6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_timeUp)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.error),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.timer_off, size: 14, color: AppColors.error),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Time's up! Submit Attack is disabled - you can still Run Tests for feedback.",
                              style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber, size: 14, color: AppColors.error),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Dazed by ${enemy.vulnerability}, -15% DEF',
                            style: const TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Challenge spec card
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () => setState(() => _specExpanded = !_specExpanded),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(question.title,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.onSurface)),
                                      const SizedBox(height: 4),
                                      Text('${question.difficulty} · ${question.tags.join(" · ")}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                                Icon(_specExpanded ? Icons.expand_less : Icons.expand_more, color: AppColors.onSurfaceVariant),
                              ],
                            ),
                          ),
                        ),
                        if (_specExpanded)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(question.prompt, style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant, height: 1.5)),
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerLowest,
                                    borderRadius: BorderRadius.circular(AppRadius.lg),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Input: ${question.exampleInput}', style: AppTheme.mono(fontSize: 11, color: AppColors.secondary)),
                                      const SizedBox(height: 4),
                                      Text('Output: ${question.exampleOutput}', style: AppTheme.mono(fontSize: 11, color: AppColors.tertiary)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  CodeEditorPanel(
                    // A new key (new battle or language switch) remounts the
                    // editor with fresh starter code; otherwise this same
                    // instance - and its TextEditingController - persists
                    // across the timer's per-second rebuilds, so typing never
                    // gets fought by a reset cursor. See CodeEditorPanel's
                    // own doc comment for why this matters.
                    key: ValueKey('${state.battleId}_${state.currentLanguage}'),
                    filename: 'SOLUTION.${_ext(state.currentLanguage)}',
                    initialCode: state.currentCode ?? '',
                    onChanged: state.updateCode,
                  ),
                  const SizedBox(height: 16),
                  Text('Test Cases', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
                  const SizedBox(height: 10),
                  if (_lastRun == null)
                    const Text('Run tests to see results.', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant))
                  else ...[
                    Text('${_lastRun!.passedTests}/${_lastRun!.totalTests} TESTS PASSED',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _lastRun!.passedTests == _lastRun!.totalTests ? AppColors.secondary : AppColors.error,
                        )),
                    const SizedBox(height: 4),
                    Text('${_lastRun!.correctnessPercent}% SOLUTION ACCURACY',
                        style: AppTheme.mono(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.tertiary)),
                    if (_lastRun!.damageDealt > 0) ...[
                      const SizedBox(height: 4),
                      Text('DEALT ${_lastRun!.damageDealt} DAMAGE',
                          style: AppTheme.mono(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.error)),
                    ],
                    if (_lastRun!.bestScorePercent > 0)
                      Text('BEST SCORE: ${_lastRun!.bestScorePercent}%',
                          style: AppTheme.mono(fontSize: 10, color: AppColors.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    for (var i = 0; i < _lastRun!.results.length; i++)
                      TestCaseTile(index: i, result: _lastRun!.results[i]),
                  ],
                  const SizedBox(height: 90),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLow,
          border: Border(top: BorderSide(color: AppColors.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: (_isRunning || _isSubmitting) ? null : () => _runTests(context),
                  child: _isRunning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Run Tests'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: (_isRunning || _isSubmitting || _timeUp) ? null : () => _submitAttack(context),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_timeUp ? "Time's Up" : 'Submit Attack'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runTests(BuildContext context) async {
    final state = context.read<GameState>();
    setState(() => _isRunning = true);
    try {
      final result = await state.runTests();
      if (!context.mounted) return;
      setState(() => _lastRun = result);
    } on BattleApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  String _ext(String lang) {
    switch (lang) {
      case 'typescript':
        return 'TS';
      case 'cpp':
        return 'CPP';
      default:
        return 'PY';
    }
  }

  Future<void> _submitAttack(BuildContext context) async {
    final state = context.read<GameState>();
    setState(() => _isSubmitting = true);
    try {
      final result = await state.submitAttack();
      if (!context.mounted) return;
      setState(() => _lastRun = result);
      // Only navigate away when the battle is actually finalized - an
      // ordinary partial-credit submit that leaves the battle "in_progress"
      // just updates the on-screen HP bar/stats so the user can keep
      // iterating on their solution.
      if (!result.finalized) return;
      if (result.won) {
        context.pushReplacement('/victory');
      } else {
        context.pushReplacement('/defeat');
      }
    } on BattleApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
