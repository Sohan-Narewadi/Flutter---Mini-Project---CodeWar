import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/level_node.dart';
import '../providers/game_state.dart';
import '../ui/app_card.dart';
import '../ui/app_scaffold.dart';
import '../utils/theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/difficulty_chip.dart';
import '../widgets/enemy_card.dart';

/// Battle Arena: every encounter in one list, filterable by difficulty.
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
      navIndex: -1,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          PageHeader(
            title: 'Battle Arena',
            subtitle: 'Take on enemies for XP and gold. Wrong answers cost HP.',
            trailing: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
            child: DifficultyFilterBar(selected: _filter, onSelected: (d) => setState(() => _filter = d)),
          ),
          const SizedBox(height: 14),
          if (enemies.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpace.page),
              child: AppCard(child: Text('No enemies match this filter.', style: TextStyle(color: AppColors.textDim))),
            )
          else
            for (final enemy in enemies)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.page, 0, AppSpace.page, 12),
                child: EnemyCard(
                  enemy: enemy,
                  onFight: enemy.locked ? null : () => context.push('/prepare/${enemy.id}'),
                ),
              ),
        ],
      ),
    );
  }
}
