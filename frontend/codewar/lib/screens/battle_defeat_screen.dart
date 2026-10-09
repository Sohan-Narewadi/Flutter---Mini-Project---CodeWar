import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/game_state.dart';
import '../utils/theme.dart';
import '../widgets/no_result_redirect.dart';

class BattleDefeatScreen extends StatelessWidget {
  const BattleDefeatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final result = state.lastResult;
    if (result == null) return const NoResultRedirect();
    final enemy = state.currentEnemy;
    final failedIndex = result.results.indexWhere((r) => !r.passed);
    final failedResult = failedIndex >= 0 ? result.results[failedIndex] : null;
    // An expired battle reports 0 total tests; avoid dividing by zero.
    final passedPct = result.totalTests == 0 ? 0 : ((result.passedTests / result.totalTests) * 100).round();

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
                  color: AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(color: AppColors.error),
                ),
                child: Text(
                  'DEFEAT · ${result.passedTests}/${result.totalTests} TESTS PASSED',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.error),
                ),
              ),
              const SizedBox(height: 20),
              const Icon(Icons.heart_broken, color: AppColors.error, size: 72),
              const SizedBox(height: 12),
              const Text('Battle Defeated', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.onSurface)),
              const SizedBox(height: 6),
              Text(
                '${enemy?.name ?? "Enemy"} (Lvl ${enemy?.level ?? 1}) · Encounter Lost',
                style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _statCol('Assertions', '${result.passedTests}/${result.totalTests}', '$passedPct%', AppColors.error),
                          ),
                          Expanded(
                            child: _statCol('Damage Taken', '${result.hpLost} HP', '3 ticks', AppColors.tertiary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.errorContainer.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Test ${(failedIndex >= 0 ? failedIndex : 2) + 1} Failed',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.error)),
                          const SizedBox(height: 6),
                          Text(
                            failedResult != null
                                ? 'Expected: ${failedResult.expected}, Got: ${failedResult.actual}'
                                : 'IndexError: list index out of range on empty list []',
                            style: AppTheme.mono(fontSize: 12, color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Tactical Debrief', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pattern Flaw', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.onSurface)),
                          const SizedBox(height: 6),
                          const Text(
                            'Your solution assumes the input array always has at least one element. Edge cases like an empty array need an explicit guard clause before indexing.',
                            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant, height: 1.5),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Recommended Drill', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.onSurface)),
                                      Text('Edge Case Handling · +40 XP', style: AppTheme.mono(fontSize: 11, color: AppColors.secondary)),
                                    ],
                                  ),
                                ),
                                OutlinedButton(
                                  onPressed: () => context.go('/practice'),
                                  child: const Text('Practice Drill'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.pushReplacement('/ide'),
                  child: const Text('Retry Battle (1 Energy or 50 Coins)'),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.go('/practice'),
                      child: const Text('Practice Topic'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.go('/home'),
                      child: const Text('Return to Camp'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCol(String label, String value, String sub, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(value, style: AppTheme.mono(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        Text(sub, style: AppTheme.mono(fontSize: 10, color: AppColors.onSurfaceVariant)),
      ],
    );
  }
}
