import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/language.dart';
import '../providers/practice_state.dart';
import '../utils/theme.dart';
import '../widgets/code_editor_panel.dart';
import '../widgets/test_case_tile.dart';

/// One practice problem: statement, editor, Run / Submit / Hint, results.
/// No HP is ever at stake here.
class PracticePlayScreen extends StatelessWidget {
  const PracticePlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PracticeState>();
    final session = p.session;
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Practice')),
        body: Center(
          child: TextButton(onPressed: () => context.go('/practice'), child: const Text('No active problem. Back to Practice')),
        ),
      );
    }
    final q = session.question;
    final solved = p.lastSubmit?.solved == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(session.daily ? 'Daily Challenge' : 'Practice'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(q.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.onSurface)),
              ),
              Chip(label: Text(q.difficulty), visualDensity: VisualDensity.compact),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(spacing: 6, children: [for (final t in q.tags) Chip(label: Text(t), visualDensity: VisualDensity.compact)]),
          const SizedBox(height: 10),
          Text(q.prompt, style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.onSurface)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Text('Example\n${q.exampleInput}\n=> ${q.exampleOutput}',
                style: AppTheme.mono(fontSize: 12, color: AppColors.onSurfaceVariant)),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [
              for (final l in Language.values)
                ChoiceChip(
                  key: Key('lang_${l.id}'),
                  label: Text(l.label),
                  selected: p.language == l,
                  onSelected: (_) => p.setLanguage(l),
                ),
            ],
          ),
          const SizedBox(height: 10),
          CodeEditorPanel(
            key: ValueKey('${session.practiceId}_${p.language.id}'),
            filename: 'SOLUTION.${p.language.ext}',
            initialCode: p.code,
            onChanged: p.updateCode,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                key: const Key('hintButton'),
                onPressed: p.busy ? null : p.hint,
                icon: const Icon(Icons.lightbulb_outline, size: 18),
                label: Text(p.hints.isEmpty ? 'Hint' : 'Hint (${p.hints.length})'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonal(
                  key: const Key('runButton'),
                  onPressed: p.busy ? null : p.run,
                  child: p.running ? const _Spinner() : const Text('Run Tests'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  key: const Key('submitButton'),
                  onPressed: p.busy ? null : p.submit,
                  child: p.submitting ? const _Spinner() : const Text('Submit'),
                ),
              ),
            ],
          ),
          if (p.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(p.error!, key: const Key('practiceError'), style: const TextStyle(color: AppColors.error)),
            ),
          for (final h in p.hints)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.tertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.tertiary.withValues(alpha: 0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb, size: 18, color: AppColors.tertiary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(h.text, style: const TextStyle(fontSize: 13, color: AppColors.onSurface))),
                ],
              ),
            ),
          if (solved) _SolvedCard(p: p),
          if (p.lastRun != null) ...[
            const SizedBox(height: 16),
            Text('${p.lastRun!.passedTests}/${p.lastRun!.totalTests} tests passed',
                key: const Key('testSummary'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
            const SizedBox(height: 8),
            for (var i = 0; i < p.lastRun!.results.length; i++) TestCaseTile(index: i, result: p.lastRun!.results[i]),
          ],
        ],
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2));
}

class _SolvedCard extends StatelessWidget {
  const _SolvedCard({required this.p});
  final PracticeState p;

  @override
  Widget build(BuildContext context) {
    final r = p.lastSubmit!;
    return Container(
      key: const Key('solvedCard'),
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.secondary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: AppColors.tertiary),
              const SizedBox(width: 8),
              const Text('Solved!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.onSurface)),
              const Spacer(),
              if (r.xpEarned > 0)
                Text('+${r.xpEarned} XP  +${r.goldEarned} gold',
                    style: AppTheme.mono(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.secondary))
              else
                const Text('Already rewarded', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 4),
          Text('${r.streak} day streak', style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: const Key('nextProblem'),
                  onPressed: p.starting
                      ? null
                      : () async {
                          final ok = await p.start(topicOverride: p.session?.topic);
                          if (!context.mounted) return;
                          if (!ok) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.error ?? 'Could not load next problem.')));
                          }
                        },
                  child: const Text('Next problem'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: () => context.pop(), child: const Text('Done')),
            ],
          ),
        ],
      ),
    );
  }
}
