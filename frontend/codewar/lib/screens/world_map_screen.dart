import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/level_node.dart';
import '../providers/game_state.dart';
import '../ui/app_card.dart';
import '../ui/neon_button.dart';
import '../ui/skeleton.dart';
import '../utils/theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/difficulty_chip.dart';
import '../widgets/home_header.dart';
import '../widgets/sector_tile.dart';

/// Home: player strip, a "continue" hero for the current campaign level,
/// shortcuts, and the level path. Everything shown comes from the server.
class WorldMapScreen extends StatelessWidget {
  const WorldMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();

    if (!state.hasLoaded) {
      return AppShell(
        title: 'Home',
        navIndex: 0,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            0,
            AppSpace.page,
            24,
          ),
          children: [
            const HomeHeader(),
            if (state.error != null && !state.isLoading)
              AppCard(
                accent: AppColors.danger,
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.error!,
                      key: const Key('homeError'),
                      style: const TextStyle(color: AppColors.text),
                    ),
                    const SizedBox(height: 12),
                    NeonButton(
                      label: 'Try again',
                      compact: true,
                      expanded: false,
                      onPressed: state.load,
                    ),
                  ],
                ),
              ),
            const SkeletonList(rows: 5, rowHeight: 84),
          ],
        ),
      );
    }

    final world = state.activeWorld;
    final nodes = state.world2Levels;
    final done = nodes.where((n) => n.status == NodeStatus.done).length;
    LevelNode? current;
    for (final n in nodes) {
      if (n.status == NodeStatus.current) {
        current = n;
        break;
      }
    }

    return AppShell(
      title: 'Home',
      navIndex: 0,
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.surfaceHigh,
        onRefresh: state.load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const HomeHeader(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  _ContinueCard(
                    worldName: world.name,
                    done: done,
                    total: nodes.length,
                    current: current,
                    onContinue: current == null
                        ? null
                        : () => _onNodeTap(context, current!),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _Shortcut(
                          key: const Key('openArena'),
                          icon: Icons.shield_moon_rounded,
                          title: 'Arena',
                          subtitle: 'Farm enemies',
                          onTap: () => context.push('/battle'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Shortcut(
                          icon: Icons.groups_rounded,
                          title: 'Play Online',
                          subtitle: 'Race friends',
                          onTap: () => context.go('/online'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SectionTitle(
                    'Campaign path',
                    trailing: Text(
                      '$done/${nodes.length} cleared',
                      style: AppTheme.mono(
                        fontSize: 12,
                        color: AppColors.textDim,
                      ),
                    ),
                  ),
                  for (var i = 0; i < nodes.length; i++)
                    SectorTile(
                      node: nodes[i],
                      isLast: i == nodes.length - 1,
                      onTap: () => _onNodeTap(context, nodes[i]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onNodeTap(BuildContext context, LevelNode node) {
    final state = context.read<GameState>();
    final enemy = state.enemyById(node.enemyId);
    context.push('/prepare/${enemy.id}?levelId=${node.id}');
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.worldName,
    required this.done,
    required this.total,
    required this.current,
    required this.onContinue,
  });

  final String worldName;
  final int done;
  final int total;
  final LevelNode? current;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : done / total;
    final complete = current == null && total > 0 && done == total;
    return AppCard(
      accent: AppColors.accent,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                worldName.toUpperCase(),
                style: AppTheme.overline(color: AppColors.accent),
              ),
              const Spacer(),
              if (current != null)
                DifficultyChip(difficulty: current!.difficulty, compact: true),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            complete
                ? 'Sector cleared'
                : (current?.name ?? 'No level available'),
            style: AppTheme.display(fontSize: 24, height: 1.1),
          ),
          const SizedBox(height: 6),
          Text(
            complete
                ? 'You cleared every level here. Keep sharp in Practice or race friends online.'
                : current == null
                ? 'Pull down to refresh.'
                : 'Level ${current!.order} · +${current!.xpReward} XP · +${current!.goldReward} gold',
            style: const TextStyle(color: AppColors.textDim, fontSize: 13),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: AppColors.line,
              color: AppColors.accent,
            ),
          ),
          if (onContinue != null) ...[
            const SizedBox(height: 16),
            NeonButton(
              key: const Key('continueButton'),
              label: 'Continue',
              icon: Icons.play_arrow_rounded,
              onPressed: onContinue,
            ),
          ],
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: AppColors.accent, size: 22),
          ),
          const SizedBox(height: 10),
          Text(title, style: AppTheme.display(fontSize: 16)),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textDim, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
