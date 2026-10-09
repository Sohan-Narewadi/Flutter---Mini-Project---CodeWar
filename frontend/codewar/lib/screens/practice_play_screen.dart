import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/language.dart';
import '../providers/practice_state.dart';
import '../ui/app_card.dart';
import '../ui/app_scaffold.dart';
import '../ui/neon_button.dart';
import '../ui/segmented_tabs.dart';
import '../utils/theme.dart';
import '../widgets/code_editor_panel.dart';
import '../widgets/difficulty_chip.dart';
import '../widgets/test_case_tile.dart';
import '../models/level_node.dart';

/// One practice problem: statement, editor, Run / Submit / Hint, results.
/// No HP is ever at stake here. The action bar is docked so it never scrolls
/// away from the editor.
class PracticePlayScreen extends StatelessWidget {
  const PracticePlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PracticeState>();
    final session = p.session;
    if (session == null) {
      return AppScaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.terminal_rounded, size: 40, color: AppColors.textFaint),
                const SizedBox(height: 12),
                const Text('No active problem.', style: TextStyle(color: AppColors.textDim)),
                const SizedBox(height: 16),
                NeonButton(label: 'Back to Practice', expanded: false, onPressed: () => context.go('/practice')),
              ],
            ),
          ),
        ),
      );
    }
    final q = session.question;
    final solved = p.lastSubmit?.solved == true;
    final difficulty = difficultyFromString(q.difficulty);

    return AppScaffold(
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, AppSpace.page, 4),
            child: Row(
              children: [
                IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.canPop() ? context.pop() : context.go('/practice')),
                Expanded(child: Text(session.daily ? 'DAILY CHALLENGE' : 'PRACTICE', style: AppTheme.overline(color: session.daily ? AppColors.gold : AppColors.accent))),
                DifficultyChip(difficulty: difficulty),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpace.page, 4, AppSpace.page, 20),
              children: [
                Text(q.title, style: AppTheme.display(fontSize: 26, height: 1.1)),
                if (q.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: [for (final t in q.tags) _Tag(t)]),
                ],
                const SizedBox(height: 14),
                Text(q.prompt, style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.text)),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLowest,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('EXAMPLE', style: AppTheme.overline()),
                      const SizedBox(height: 8),
                      Text('Input   ${q.exampleInput}', style: AppTheme.mono(fontSize: 12.5, color: AppColors.accent)),
                      const SizedBox(height: 4),
                      Text('Output  ${q.exampleOutput}', style: AppTheme.mono(fontSize: 12.5, color: AppColors.gold)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SegmentedTabs<Language>(
                  key: const Key('languageTabs'),
                  height: 40,
                  options: {for (final l in Language.values) l: l.label},
                  value: p.language,
                  onChanged: p.setLanguage,
                ),
                const SizedBox(height: 12),
                CodeEditorPanel(
                  key: ValueKey('${session.practiceId}_${p.language.id}'),
                  filename: 'solution.${p.language.ext}',
                  initialCode: p.code,
                  onChanged: p.updateCode,
                ),
                if (p.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.danger),
                        const SizedBox(width: 8),
                        Expanded(child: Text(p.error!, key: const Key('practiceError'), style: const TextStyle(color: AppColors.danger, height: 1.3))),
                      ],
                    ),
                  ),
                for (final h in p.hints) _HintCard(level: h.level, text: h.text),
                if (solved) _SolvedCard(p: p),
                if (p.lastRun != null) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text('RESULTS', style: AppTheme.overline()),
                      const Spacer(),
                      Text(
                        '${p.lastRun!.passedTests}/${p.lastRun!.totalTests} tests passed',
                        key: const Key('testSummary'),
                        style: AppTheme.display(
                          fontSize: 14,
                          color: p.lastRun!.passedTests == p.lastRun!.totalTests ? AppColors.success : AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < p.lastRun!.results.length; i++) TestCaseTile(index: i, result: p.lastRun!.results[i]),
                ],
              ],
            ),
          ),
          _ActionBar(p: p),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(AppRadius.full), border: Border.all(color: AppColors.line)),
        child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textDim, fontWeight: FontWeight.w600)),
      );
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.p});
  final PracticeState p;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 12, AppSpace.page, 12),
      decoration: const BoxDecoration(color: AppColors.surfaceLow, border: Border(top: BorderSide(color: AppColors.line))),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: NeonButton(
                key: const Key('hintButton'),
                label: 'Hint',
                iconOnly: true,
                icon: Icons.lightbulb_outline_rounded,
                variant: NeonVariant.secondary,
                loading: p.hinting,
                onPressed: p.busy ? null : p.hint,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: NeonButton(
                key: const Key('runButton'),
                label: 'Run',
                icon: Icons.play_arrow_rounded,
                variant: NeonVariant.secondary,
                loading: p.running,
                onPressed: p.busy ? null : p.run,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 4,
              child: NeonButton(
                key: const Key('submitButton'),
                label: 'Submit',
                icon: Icons.bolt_rounded,
                loading: p.submitting,
                onPressed: p.busy ? null : p.submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.level, required this.text});
  final int level;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_rounded, size: 18, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HINT $level', style: AppTheme.overline(color: AppColors.gold)),
                const SizedBox(height: 4),
                Text(text, style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.text)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SolvedCard extends StatelessWidget {
  const _SolvedCard({required this.p});
  final PracticeState p;

  @override
  Widget build(BuildContext context) {
    final r = p.lastSubmit!;
    return Container(
      key: const Key('solvedCard'),
      margin: const EdgeInsets.only(top: 16),
      child: AppCard(
        accent: AppColors.success,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
                const SizedBox(width: 10),
                Text('Solved!', style: AppTheme.display(fontSize: 24, color: AppColors.success)),
              ],
            ),
            const SizedBox(height: 10),
            if (r.xpEarned > 0)
              Text('+${r.xpEarned} XP   +${r.goldEarned} gold', style: AppTheme.display(fontSize: 18, color: AppColors.gold))
            else
              const Text('Already rewarded. Solve something new for more XP.', style: TextStyle(color: AppColors.textDim)),
            const SizedBox(height: 4),
            Text('${r.streak} day streak', style: const TextStyle(fontSize: 13, color: AppColors.textDim)),
            for (final b in r.newBadges) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.gold.withValues(alpha: 0.5))),
                child: Row(
                  children: [
                    Icon(b.iconData, color: AppColors.gold),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BADGE UNLOCKED', style: AppTheme.overline(color: AppColors.gold)),
                          Text('${b.name}: ${b.description}', style: const TextStyle(fontSize: 13, color: AppColors.text)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: NeonButton(
                    key: const Key('nextProblem'),
                    label: 'Next problem',
                    icon: Icons.arrow_forward_rounded,
                    loading: p.starting,
                    onPressed: p.starting
                        ? null
                        : () async {
                            final ok = await p.start(topicOverride: p.session?.topic);
                            if (!context.mounted) return;
                            if (!ok) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.error ?? 'Could not load next problem.')));
                            }
                          },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: NeonButton(label: 'Done', variant: NeonVariant.secondary, onPressed: () => context.canPop() ? context.pop() : context.go('/practice'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
