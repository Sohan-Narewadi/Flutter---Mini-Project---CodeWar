import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/battle.dart';
import '../models/enemy.dart';
import '../models/level_node.dart';
import '../providers/game_state.dart';
import '../utils/theme.dart';
import '../widgets/hp_xp_bar.dart';

/// Battle Preparation / Loadout screen: match-up card, weakness readout,
/// loadout slots, language picker, rewards preview, and the CTA that kicks
/// off the actual coding battle.
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

    return Scaffold(
      appBar: AppBar(title: const Text('Battle Preparation')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Match-up card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('YOU', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.secondary)),
                            const SizedBox(height: 4),
                            Text(player.displayName, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                          ],
                        ),
                      ),
                      const Icon(Icons.bolt, color: AppColors.tertiary),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('ENEMY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.error)),
                            const SizedBox(height: 4),
                            Text(enemy.name, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  HpXpBar(progress: player.hpProgress, color: AppColors.secondary, label: 'HP', trailing: '${player.hp}/${player.hpMax}'),
                  const SizedBox(height: 10),
                  HpXpBar(progress: enemy.hpProgress, color: AppColors.error, label: 'ENEMY HP', trailing: '${enemy.hpCurrent}/${enemy.hpMax}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _infoGrid(enemy),
            const SizedBox(height: 20),
            const Text('Loadout', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
            const SizedBox(height: 10),
            _loadoutSlot(Icons.gavel, 'Logic Blade Mk II', 'Primary Weapon', '+15% syntax speed, +20 critical test dmg', locked: false),
            _loadoutSlot(Icons.shield, 'Debug Shield', 'Defense', 'Blocks 1 failed test penalty', locked: true),
            _loadoutSlot(Icons.smart_toy, 'Byte Bot v1.4', 'Support', '1 hint w/o coin penalty', locked: false),
            const SizedBox(height: 20),
            const Text('Language', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                _langChip('python', 'Python 3'),
                _langChip('typescript', 'TypeScript'),
                _langChip('cpp', 'C++ 20'),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _rewardMini(Icons.bolt, '+${enemy.xpReward} XP', AppColors.secondary),
                  _rewardMini(Icons.monetization_on, '+${enemy.goldReward} Coins', AppColors.tertiary),
                  _rewardMini(Icons.auto_awesome, '+1 Skill Pt', AppColors.primary),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _starting ? null : () => _confirmAndFight(context, enemy.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(_starting ? 'Loading Battle...' : 'Confirm Loadout & Fight (10 Energy)'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoGrid(Enemy enemy) {
    return Row(
      children: [
        Expanded(child: _infoTile('Weakness', enemy.vulnerability, AppColors.secondary)),
        const SizedBox(width: 10),
        Expanded(child: _infoTile('Target', 'O(N)', AppColors.tertiary)),
        const SizedBox(width: 10),
        Expanded(child: _infoTile('Time Limit', '5 min', AppColors.error)),
      ],
    );
  }

  Widget _infoTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: AppTheme.mono(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _loadoutSlot(IconData icon, String name, String slot, String desc, {required bool locked}) {
    return Opacity(
      opacity: locked ? 0.5 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(locked ? Icons.lock : icon, color: locked ? AppColors.outline : AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.onSurface)),
                      const SizedBox(width: 6),
                      Text('· $slot', style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                  Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            if (!locked) const Icon(Icons.check_circle, color: AppColors.secondary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _langChip(String value, String label) {
    final selected = _language == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _language = value),
      selectedColor: AppColors.primary.withValues(alpha: 0.25),
      labelStyle: TextStyle(color: selected ? AppColors.primary : AppColors.onSurfaceVariant, fontWeight: FontWeight.w700),
      side: BorderSide(color: selected ? AppColors.primary : AppColors.outlineVariant),
    );
  }

  Widget _rewardMini(IconData icon, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(label, style: AppTheme.mono(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ],
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
