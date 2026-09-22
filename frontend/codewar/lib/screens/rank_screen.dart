import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_state.dart';
import '../utils/theme.dart';
import '../widgets/app_shell.dart';

class _LeaderEntry {
  final int rank;
  final String name;
  final int level;
  final int xp;
  final bool isPlayer;
  const _LeaderEntry(this.rank, this.name, this.level, this.xp, {this.isPlayer = false});
}

/// Rank: a leaderboard built from local/seeded data plus the real player
/// stats from GameState so the player's own row reflects live state.
class RankScreen extends StatelessWidget {
  const RankScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<GameState>().player;

    final board = <_LeaderEntry>[
      const _LeaderEntry(1, 'ByteReaper', 19, 18200),
      const _LeaderEntry(2, 'NullPointerX', 17, 15100),
      const _LeaderEntry(3, 'HeapQueen', 15, 12980),
      _LeaderEntry(4, player.displayName, player.level, player.xp, isPlayer: true),
      const _LeaderEntry(5, 'StackOverflowJoe', 11, 9800),
      const _LeaderEntry(6, 'RecursiveRhea', 10, 8700),
      const _LeaderEntry(7, 'GreedyGary', 9, 7400),
    ];

    return AppShell(
      title: 'Rank',
      navIndex: 3,
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: board.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text('Sector Leaderboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
            );
          }
          final entry = board[i - 1];
          final medalColor = entry.rank == 1
              ? AppColors.tertiary
              : entry.rank == 2
                  ? AppColors.onSurfaceVariant
                  : entry.rank == 3
                      ? const Color(0xFFCD7F32)
                      : AppColors.outline;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: entry.isPlayer ? AppColors.surfaceContainerHigh : AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: entry.isPlayer ? AppColors.primary : AppColors.outlineVariant),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text('#${entry.rank}',
                      style: TextStyle(fontWeight: FontWeight.w800, color: medalColor, fontSize: 14)),
                ),
                Expanded(
                  child: Text(
                    entry.name + (entry.isPlayer ? ' (You)' : ''),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.onSurface, fontSize: 13),
                  ),
                ),
                Text('Lv.${entry.level}', style: AppTheme.mono(fontSize: 12, color: AppColors.onSurfaceVariant)),
                const SizedBox(width: 12),
                Text('${entry.xp} XP', style: AppTheme.mono(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.secondary)),
              ],
            ),
          );
        },
      ),
    );
  }
}
