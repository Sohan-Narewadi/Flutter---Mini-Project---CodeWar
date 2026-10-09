import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/level_node.dart';
import '../providers/game_state.dart';
import '../widgets/app_shell.dart';
import '../widgets/difficulty_chip.dart';
import '../widgets/enemy_card.dart';

/// Battle Arena: browse-all-encounters screen, filterable by difficulty.
class BattleArenaScreen extends StatefulWidget {
  const BattleArenaScreen({super.key});

  @override
  State<BattleArenaScreen> createState() => _BattleArenaScreenState();
}

class _BattleArenaScreenState extends State<BattleArenaScreen> {
  Difficulty? _filter;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final enemies = state.enemies.where((e) => _filter == null || e.difficulty == _filter).toList();

    return AppShell(
      title: 'Battle Arena',
      navIndex: 1,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: InkWell(
              key: const Key('playOnlineBanner'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push('/online'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFA078FF), Color(0xFF00A6E0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.public, color: Colors.white, size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Play Online', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                          Text('Race or duel friends with a room code', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: DifficultyFilterBar(selected: _filter, onSelected: (d) => setState(() => _filter = d)),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: enemies.length,
              itemBuilder: (context, i) {
                final enemy = enemies[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: EnemyCard(
                    enemy: enemy,
                    onFight: enemy.locked ? null : () => context.push('/prepare/${enemy.id}'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
