import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/battle.dart';
import '../models/level_node.dart';
import '../providers/game_state.dart';
import '../ui/app_card.dart';
import '../ui/app_scaffold.dart';
import '../ui/neon_button.dart';
import '../ui/segmented_tabs.dart';
import '../ui/stat_tile.dart';
import '../utils/theme.dart';
import '../widgets/hp_xp_bar.dart';

/// Battle preparation: the match-up, the enemy's topic, language choice, the
/// rewards on offer, and the button that starts the real (server-issued) battle.
class BattlePreparationScreen extends StatefulWidget {
  const BattlePreparationScreen({super.key, required this.enemyId, this.levelId});

  final String enemyId;
  final String? levelId;

  @override
  State<BattlePreparationScreen> createState() => _BattlePreparationScreenState();
}

class _BattlePreparationScreenState extends State<BattlePreparationScreen> {
  String _language = 'python';
  bool _starting = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final enemy = state.enemyById(widget.enemyId);
    final player = state.player;
    final lowHp = player.hp <= player.hpMax * 0.25;

    return AppScaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, AppSpace.page, 0),
            child: Row(
              children: [
                IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.canPop() ? context.pop() : context.go('/home')),
                Text('Battle preparation', style: AppTheme.display(fontSize: 22)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpace.page, 12, AppSpace.page, 24),
              children: [
                AppCard(
                  accent: AppColors.danger,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('YOU', style: AppTheme.overline(color: AppColors.accent)),
                                const SizedBox(height: 4),
                                Text(player.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.display(fontSize: 18)),
                              ],
                            ),
                          ),
                          const Icon(Icons.flash_on_rounded, color: AppColors.gold),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('ENEMY', style: AppTheme.overline(color: AppColors.danger)),
                                const SizedBox(height: 4),
                                Text(enemy.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.display(fontSize: 18)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      HpXpBar(progress: player.hpProgress, color: AppColors.accent, label: 'YOUR HP', trailing: '${player.hp}/${player.hpMax}', height: 8),
                      const SizedBox(height: 12),
                      HpXpBar(progress: enemy.hpProgress, color: AppColors.danger, label: 'ENEMY HP', trailing: '${enemy.hpCurrent}/${enemy.hpMax}', height: 8),
                    ],
                  ),
                ),
                if (lowHp) ...[
                  const SizedBox(height: 12),
                  AppCard(
                    accent: AppColors.gold,
                    padding: const EdgeInsets.all(14),
                    child: const Row(
                      children: [
                        Icon(Icons.favorite_rounded, color: AppColors.gold, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your HP is low. A wrong submission costs HP and can end the fight. HP regenerates slowly over time, or practice instead (no HP at stake).',
                            style: TextStyle(color: AppColors.text, fontSize: 13, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _InfoTile(label: 'Topic', value: enemy.vulnerability.isEmpty ? 'Mixed' : enemy.vulnerability)),
                    const SizedBox(width: 10),
                    Expanded(child: _InfoTile(label: 'Tier', value: enemy.tier.isEmpty ? 'Minion' : '${enemy.tier[0].toUpperCase()}${enemy.tier.substring(1)}')),
                    const SizedBox(width: 10),
                    Expanded(child: _InfoTile(label: 'Difficulty', value: difficultyLabel(enemy.difficulty))),
                  ],
                ),
                const SizedBox(height: 22),
                Text('LANGUAGE', style: AppTheme.overline()),
                const SizedBox(height: 8),
                SegmentedTabs<String>(
                  options: const {'python': 'Python 3', 'typescript': 'TypeScript'},
                  value: _language,
                  onChanged: (v) => setState(() => _language = v),
                ),
                const SizedBox(height: 22),
                Text('REWARDS', style: AppTheme.overline()),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: StatTile(icon: Icons.bolt_rounded, color: AppColors.accent, value: '+${enemy.xpReward}', label: 'XP')),
                    const SizedBox(width: 10),
                    Expanded(child: StatTile(icon: Icons.monetization_on_rounded, color: AppColors.gold, value: '+${enemy.goldReward}', label: 'Gold')),
                  ],
                ),
                const SizedBox(height: 26),
                NeonButton(
                  key: const Key('startBattle'),
                  label: 'Start battle',
                  icon: Icons.sports_martial_arts_rounded,
                  loading: _starting,
                  onPressed: _starting ? null : () => _confirmAndFight(context, enemy.id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndFight(BuildContext context, String enemyId) async {
    setState(() => _starting = true);
    final state = context.read<GameState>();
    state.setLanguage(_language);
    final enemy = state.enemyById(enemyId);
    // Prefer the explicit levelId carried through navigation (World Map's
    // sector nodes send this). Routes that don't carry one - Battle Arena's
    // "Fight" button, Practice's farmable-enemy cards - fall back to
    // resolving the level generically via the enemy's own backend
    // association, so this isn't tied to any specific level/enemy.
    final matchingLevels = widget.levelId == null
        ? const Iterable<LevelNode>.empty()
        : state.levels.where((l) => l.id == widget.levelId);
    final level = matchingLevels.isNotEmpty ? matchingLevels.first : state.levelForEnemy(enemyId);
    try {
      await state.startBattle(enemy: enemy, level: level);
      if (!context.mounted) return;
      context.push('/ide');
    } on BattleApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppTheme.overline()),
          const SizedBox(height: 6),
          Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTheme.display(fontSize: 14, height: 1.15)),
        ],
      ),
    );
  }
}
