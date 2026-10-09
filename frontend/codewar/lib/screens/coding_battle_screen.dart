import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/battle.dart';
import '../models/level_node.dart';
import '../providers/game_state.dart';
import '../services/sfx.dart';
import '../ui/app_card.dart';
import '../ui/app_scaffold.dart';
import '../ui/neon_button.dart';
import '../ui/shake.dart';
import '../utils/theme.dart';
import '../widgets/code_editor_panel.dart';
import '../widgets/difficulty_chip.dart';
import '../widgets/hp_xp_bar.dart';
import '../widgets/test_case_tile.dart';

/// Coding Battle IDE: live timer, dual HP gauges, challenge spec, code
/// editor, test runner panel, and the Run / Submit Attack actions.
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
      return AppScaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shield_moon_rounded, size: 40, color: AppColors.textFaint),
              const SizedBox(height: 12),
              const Text('No active battle.', style: TextStyle(color: AppColors.textDim)),
              const SizedBox(height: 16),
              NeonButton(label: 'Back to Battle Arena', expanded: false, onPressed: () => context.go('/battle')),
            ],
          ),
        ),
      );
    }

    _seedTimerIfNeeded(state);
    final lowTime = _secondsLeft <= 30;

    return AppScaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, AppSpace.page, 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.canPop() ? context.pop() : context.go('/battle'),
                ),
                Expanded(child: Text('BOSS FIGHT · ${enemy.name.toUpperCase()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.overline(color: AppColors.accent))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (lowTime ? AppColors.danger : AppColors.gold).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: (lowTime ? AppColors.danger : AppColors.gold).withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_rounded, size: 16, color: lowTime ? AppColors.danger : AppColors.gold),
                      const SizedBox(width: 6),
                      Text(_clock, key: const Key('battleClock'), style: AppTheme.display(fontSize: 16, color: lowTime ? AppColors.danger : AppColors.gold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpace.page, 8, AppSpace.page, 20),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: HpXpBar(
                        progress: player.hpProgress,
                        color: AppColors.accent,
                        label: 'YOU',
                        trailing: '${player.hp}/${player.hpMax}',
                        height: 8,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ShakeOnDecrease(
                        trigger: state.enemyHpRemaining,
                        child: HpXpBar(
                          progress: state.enemyHpMax == 0 ? 0 : state.enemyHpRemaining / state.enemyHpMax,
                          color: AppColors.danger,
                          label: enemy.name.toUpperCase(),
                          trailing: '${state.enemyHpRemaining}/${state.enemyHpMax}',
                          height: 8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_timeUp)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      accent: AppColors.danger,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: const Row(
                        children: [
                          Icon(Icons.timer_off_rounded, size: 18, color: AppColors.danger),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Time's up! Submit Attack is disabled. You can still run tests for feedback.",
                              style: TextStyle(fontSize: 13, color: AppColors.danger, fontWeight: FontWeight.w600, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        onTap: () => setState(() => _specExpanded = !_specExpanded),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(question.title, style: AppTheme.display(fontSize: 20, height: 1.15)),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        DifficultyChip(difficulty: difficultyFromString(question.difficulty), compact: true),
                                        if (question.tags.isNotEmpty) Text(question.tags.join(' · '), style: const TextStyle(fontSize: 12, color: AppColors.textDim)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(_specExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppColors.textDim),
                            ],
                          ),
                        ),
                      ),
                      if (_specExpanded)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(question.prompt, style: const TextStyle(fontSize: 14, color: AppColors.text, height: 1.5)),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLowest,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  border: Border.all(color: AppColors.line),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Input   ${question.exampleInput}', style: AppTheme.mono(fontSize: 12.5, color: AppColors.accent)),
                                    const SizedBox(height: 4),
                                    Text('Output  ${question.exampleOutput}', style: AppTheme.mono(fontSize: 12.5, color: AppColors.gold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                CodeEditorPanel(
                  // A new key (new battle or language switch) remounts the
                  // editor with fresh starter code; otherwise this same
                  // instance - and its TextEditingController - persists
                  // across the timer's per-second rebuilds, so typing never
                  // gets fought by a reset cursor. See CodeEditorPanel's
                  // own doc comment for why this matters.
                  key: ValueKey('${state.battleId}_${state.currentLanguage}'),
                  filename: 'solution.${_ext(state.currentLanguage)}',
                  initialCode: state.currentCode ?? '',
                  onChanged: state.updateCode,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('RESULTS', style: AppTheme.overline()),
                    const Spacer(),
                    if (_lastRun != null)
                      Text(
                        '${_lastRun!.passedTests}/${_lastRun!.totalTests} tests passed',
                        style: AppTheme.display(
                          fontSize: 14,
                          color: _lastRun!.passedTests == _lastRun!.totalTests ? AppColors.success : AppColors.danger,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_lastRun == null)
                  const Text('Run the tests to see how your code does.', style: TextStyle(fontSize: 13, color: AppColors.textDim))
                else ...[
                  Wrap(
                    spacing: 14,
                    runSpacing: 4,
                    children: [
                      Text('${_lastRun!.correctnessPercent}% accuracy', style: AppTheme.mono(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gold)),
                      if (_lastRun!.damageDealt > 0)
                        Text('${_lastRun!.damageDealt} damage dealt', style: AppTheme.mono(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.danger)),
                      if (_lastRun!.bestScorePercent > 0)
                        Text('best ${_lastRun!.bestScorePercent}%', style: AppTheme.mono(fontSize: 12, color: AppColors.textDim)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < _lastRun!.results.length; i++) TestCaseTile(index: i, result: _lastRun!.results[i]),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(AppSpace.page, 12, AppSpace.page, 12),
            decoration: const BoxDecoration(color: AppColors.surfaceLow, border: Border(top: BorderSide(color: AppColors.line))),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: NeonButton(
                      key: const Key('battleRun'),
                      label: 'Run',
                      icon: Icons.play_arrow_rounded,
                      variant: NeonVariant.secondary,
                      loading: _isRunning,
                      onPressed: (_isRunning || _isSubmitting) ? null : () => _runTests(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: NeonButton(
                      key: const Key('battleSubmit'),
                      label: _timeUp ? "Time's Up" : 'Submit Attack',
                      icon: Icons.bolt_rounded,
                      loading: _isSubmitting,
                      onPressed: (_isRunning || _isSubmitting || _timeUp) ? null : () => _submitAttack(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
        return 'ts';
      case 'cpp':
        return 'cpp';
      default:
        return 'py';
    }
  }

  Future<void> _submitAttack(BuildContext context) async {
    final state = context.read<GameState>();
    setState(() => _isSubmitting = true);
    try {
      final result = await state.submitAttack();
      if (!context.mounted) return;
      setState(() => _lastRun = result);
      Sfx.play(result.damageDealt > 0 ? Cue.success : Cue.error);
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
