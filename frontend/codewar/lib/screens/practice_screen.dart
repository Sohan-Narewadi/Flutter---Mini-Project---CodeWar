import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/practice.dart';
import '../providers/practice_state.dart';
import '../ui/app_card.dart';
import '../ui/app_scaffold.dart';
import '../ui/segmented_tabs.dart';
import '../ui/skeleton.dart';
import '../ui/stat_tile.dart';
import '../utils/theme.dart';
import '../widgets/app_shell.dart';

/// Practice hub: an endless stream of fresh problems by difficulty and topic,
/// plus the daily challenge. All numbers come from the server.
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
    final stats = p.stats;
    return AppShell(
      title: 'Practice',
      navIndex: 1,
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.surfaceHigh,
        onRefresh: p.loadStats,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const PageHeader(title: 'Practice', subtitle: 'Endless fresh problems. Every solve builds mastery.'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: StatTile(icon: Icons.local_fire_department_rounded, color: AppColors.gold, value: '${stats.streak}', label: 'Streak')),
                      const SizedBox(width: 10),
                      Expanded(child: StatTile(icon: Icons.check_circle_rounded, color: AppColors.success, value: '${stats.solvedToday}', label: 'Today')),
                      const SizedBox(width: 10),
                      Expanded(child: StatTile(icon: Icons.emoji_events_rounded, color: AppColors.accent, value: '${stats.totalSolved}', label: 'Solved')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _DailyCard(
                    busy: p.starting,
                    done: stats.dailyDone,
                    resetsIn: stats.dailyResetsLabel,
                    onTap: () => _start(context, daily: true),
                  ),
                  const SizedBox(height: 24),
                  Text('DIFFICULTY', style: AppTheme.overline()),
                  const SizedBox(height: 8),
                  SegmentedTabs<String>(
                    options: const {'easy': 'Easy', 'medium': 'Medium', 'hard': 'Hard'},
                    value: p.difficulty,
                    onChanged: p.setDifficulty,
                  ),
                  const SizedBox(height: 24),
                  SectionTitle(
                    'Topics',
                    trailing: GestureDetector(
                      key: const Key('randomPractice'),
                      behavior: HitTestBehavior.opaque,
                      onTap: p.starting ? null : () => _start(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shuffle_rounded, size: 16, color: AppColors.accent),
                            const SizedBox(width: 6),
                            Text('Surprise me', style: AppTheme.display(fontSize: 14, color: AppColors.accent)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (p.statsError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        accent: AppColors.danger,
                        child: Row(
                          children: [
                            const Icon(Icons.cloud_off_rounded, color: AppColors.danger),
                            const SizedBox(width: 10),
                            Expanded(child: Text(p.statsError!, style: const TextStyle(color: AppColors.text))),
                            TextButton(onPressed: p.loadStats, child: const Text('Retry')),
                          ],
                        ),
                      ),
                    ),
                  if (stats.topics.isEmpty && p.loadingStats)
                    const _TopicSkeletons()
                  else
                    _TopicGrid(
                      topics: stats.topics,
                      enabled: !p.starting,
                      onTap: (t) => _start(context, topic: t.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.busy, required this.done, required this.resetsIn, required this.onTap});
  final bool busy;
  final bool done;
  final String resetsIn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = done
        ? 'Completed today${resetsIn.isEmpty ? '' : ' · new one in $resetsIn'}'
        : 'One shared puzzle for everyone. Double XP on your first solve${resetsIn.isEmpty ? '' : ' · $resetsIn left'}.';
    return AppCard(
      key: const Key('dailyChallenge'),
      onTap: busy ? null : onTap,
      padding: const EdgeInsets.all(18),
      gradient: done
          ? null
          : LinearGradient(
              colors: [AppColors.accentDeep.withValues(alpha: 0.55), AppColors.accent.withValues(alpha: 0.30)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
      accent: done ? AppColors.success : AppColors.accent,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(done ? Icons.check_rounded : Icons.today_rounded, color: done ? AppColors.success : AppColors.text, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DAILY CHALLENGE', style: AppTheme.overline(color: done ? AppColors.success : AppColors.text.withValues(alpha: 0.8))),
                const SizedBox(height: 3),
                Text(done ? 'Nice work' : 'Today\'s puzzle', style: AppTheme.display(fontSize: 20, height: 1.1)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textDim, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          busy
              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
              : const Icon(Icons.arrow_forward_rounded, color: AppColors.text),
        ],
      ),
    );
  }
}

class _TopicGrid extends StatelessWidget {
  const _TopicGrid({required this.topics, required this.enabled, required this.onTap});
  final List<TopicStat> topics;
  final bool enabled;
  final ValueChanged<TopicStat> onTap;

  @override
  Widget build(BuildContext context) {
    if (topics.isEmpty) {
      return const AppCard(child: Text('No topics available right now. Pull down to refresh.', style: TextStyle(color: AppColors.textDim)));
    }
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 12.0;
        final cols = c.maxWidth >= 480 ? 3 : 2;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final t in topics) SizedBox(width: w, child: _TopicTile(topic: t, enabled: enabled, onTap: () => onTap(t))),
          ],
        );
      },
    );
  }
}

class _TopicSkeletons extends StatelessWidget {
  const _TopicSkeletons();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [for (var i = 0; i < 6; i++) const SizedBox(width: 150, child: SkeletonBox(height: 132, radius: AppRadius.xl))],
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.topic, required this.enabled, required this.onTap});
  final TopicStat topic;
  final bool enabled;
  final VoidCallback onTap;

  static const _icons = <String, IconData>{
    'arrays': Icons.view_week_rounded,
    'strings': Icons.text_fields_rounded,
    'math': Icons.calculate_rounded,
    'hashmap': Icons.tag_rounded,
    'two-pointers': Icons.compare_arrows_rounded,
    'dp': Icons.grid_on_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final mastered = topic.masteryPercent >= 100;
    final color = mastered ? AppColors.gold : AppColors.accent;
    return AppCard(
      key: Key('topic_${topic.id}'),
      onTap: enabled ? onTap : null,
      padding: const EdgeInsets.all(14),
      accent: mastered ? AppColors.gold : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Icon(_icons[topic.id] ?? Icons.code_rounded, color: color, size: 22),
              ),
              const Spacer(),
              SizedBox(
                width: 34,
                height: 34,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: (topic.masteryPercent / 100).clamp(0.0, 1.0),
                      strokeWidth: 3,
                      backgroundColor: AppColors.line,
                      color: color,
                    ),
                    if (mastered) const Icon(Icons.star_rounded, size: 16, color: AppColors.gold),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(topic.label, maxLines: 1, style: AppTheme.display(fontSize: 17)),
          ),
          const SizedBox(height: 2),
          Text(
            topic.masteryPercent >= 100 ? 'Mastered' : 'Mastery ${topic.masteryPercent}%',
            style: TextStyle(fontSize: 12, color: mastered ? AppColors.gold : AppColors.textDim, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text('${topic.solved} solved', style: const TextStyle(fontSize: 12, color: AppColors.textFaint)),
        ],
      ),
    );
  }
}
