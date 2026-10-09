import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/practice.dart';
import '../providers/practice_state.dart';
import '../utils/theme.dart';
import '../widgets/app_shell.dart';

/// Practice hub: pick a difficulty and a topic (or go random) for an endless
/// stream of fresh problems, or take on today's daily challenge.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PracticeState>().loadStats();
    });
  }

  Future<void> _start(BuildContext context, {bool daily = false, String? topic}) async {
    final p = context.read<PracticeState>();
    final ok = await p.start(daily: daily, topicOverride: topic);
    if (!context.mounted) return;
    if (ok) {
      context.push('/practice/play');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.error ?? 'Could not start practice.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PracticeState>();
    return AppShell(
      title: 'Practice',
      navIndex: 2,
      body: RefreshIndicator(
        onRefresh: p.loadStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatsHeader(stats: p.stats),
            const SizedBox(height: 16),
            _DailyCard(
              busy: p.starting,
              solvedToday: p.stats.solvedToday > 0,
              onTap: () => _start(context, daily: true),
            ),
            const SizedBox(height: 20),
            const Text('Difficulty', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'easy', label: Text('Easy')),
                ButtonSegment(value: 'medium', label: Text('Medium')),
                ButtonSegment(value: 'hard', label: Text('Hard')),
              ],
              selected: {p.difficulty},
              onSelectionChanged: (s) => p.setDifficulty(s.first),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text('Topics', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
                ),
                FilledButton.tonalIcon(
                  key: const Key('randomPractice'),
                  onPressed: p.starting ? null : () => _start(context),
                  icon: const Icon(Icons.shuffle, size: 18),
                  label: const Text('Surprise me'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (p.statsError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(p.statsError!, style: const TextStyle(color: AppColors.error)),
              ),
            if (p.stats.topics.isEmpty && p.loadingStats)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else
              for (final t in p.stats.topics)
                _TopicTile(topic: t, enabled: !p.starting, onTap: () => _start(context, topic: t.id)),
          ],
        ),
      ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  const _StatsHeader({required this.stats});
  final PracticeStats stats;

  @override
  Widget build(BuildContext context) {
    Widget pill(IconData icon, Color color, String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.onSurface)),
                    Text(label, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
        );
    return Row(
      children: [
        pill(Icons.local_fire_department, AppColors.tertiary, '${stats.streak}', 'day streak'),
        const SizedBox(width: 12),
        pill(Icons.task_alt, AppColors.secondary, '${stats.solvedToday}', 'solved today'),
      ],
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.busy, required this.solvedToday, required this.onTap});
  final bool busy;
  final bool solvedToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('dailyChallenge'),
      borderRadius: BorderRadius.circular(AppRadius.xl),
      onTap: busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          gradient: const LinearGradient(
            colors: [AppColors.primaryContainer, AppColors.secondaryContainer],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 34, color: Colors.white),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Daily Challenge',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(
                    solvedToday
                        ? 'Same puzzle for everyone today. Double XP on the first solve.'
                        : 'A fresh medium puzzle every day. Double XP!',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
            busy
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.topic, required this.enabled, required this.onTap});
  final TopicStat topic;
  final bool enabled;
  final VoidCallback onTap;

  static const _icons = <String, IconData>{
    'arrays': Icons.view_week,
    'strings': Icons.text_fields,
    'math': Icons.calculate,
    'hashmap': Icons.tag,
    'two-pointers': Icons.compare_arrows,
    'dp': Icons.grid_on,
  };

  @override
  Widget build(BuildContext context) {
    final mastery = topic.masteryPercent / 100;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        key: Key('topic_${topic.id}'),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(_icons[topic.id] ?? Icons.code, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(topic.label,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
                        ),
                        Text('${topic.solved} solved',
                            style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: LinearProgressIndicator(
                        value: mastery,
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceContainerHighest,
                        color: mastery >= 1 ? AppColors.tertiary : AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(topic.masteryPercent >= 100 ? 'Mastered' : 'Mastery ${topic.masteryPercent}%',
                        style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
