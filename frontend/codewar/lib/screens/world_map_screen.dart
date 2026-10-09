import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/level_node.dart';
import '../providers/game_state.dart';
import '../utils/theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/sector_tile.dart';
import '../ui/app_card.dart';
import '../ui/skeleton.dart';

/// Home / World Map: shows World 2 "Array Ruins" sector progress and the
/// linear node spine. Tapping an unlocked node routes into the battle flow.
class WorldMapScreen extends StatelessWidget {
  const WorldMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final world = state.activeWorld;
    final nodes = state.world2Levels;
    final defeatedCount = nodes.where((n) => n.status == NodeStatus.done).length;

    if (!state.hasLoaded) {
      return AppShell(
        title: 'World Map',
        navIndex: 0,
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (state.error != null && !state.isLoading)
              AppCard(
                accent: AppColors.error,
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(state.error!, key: const Key('homeError'), style: const TextStyle(color: AppColors.onSurface)),
                    const SizedBox(height: 8),
                    FilledButton(onPressed: state.load, child: const Text('Try again')),
                  ],
                ),
              ),
            const SkeletonList(rows: 5, rowHeight: 78),
          ],
        ),
      );
    }

    return AppShell(
      title: 'World Map',
      navIndex: 0,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.map, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      world.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.onSurface),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  world.description,
                  style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    value: world.clearedPercent.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: AppColors.surfaceContainerHigh,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${(world.clearedPercent * 100).round()}% cleared · $defeatedCount/${nodes.length} nodes defeated',
                  style: AppTheme.mono(fontSize: 11, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('openArena'),
                  onPressed: () => context.push('/battle'),
                  icon: const Icon(Icons.gavel, size: 18),
                  label: const Text('Battle Arena'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/online'),
                  icon: const Icon(Icons.public, size: 18),
                  label: const Text('Play Online'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Sector Path', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
          const SizedBox(height: 12),
          for (var i = 0; i < nodes.length; i++)
            SectorTile(
              node: nodes[i],
              isLast: i == nodes.length - 1,
              onTap: () => _onNodeTap(context, nodes[i]),
            ),
        ],
      ),
    );
  }

  void _onNodeTap(BuildContext context, LevelNode node) {
    final state = context.read<GameState>();
    final enemy = state.enemyById(node.enemyId);
    context.push('/prepare/${enemy.id}?levelId=${node.id}');
  }
}
