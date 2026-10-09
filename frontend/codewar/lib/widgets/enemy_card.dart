import 'package:flutter/material.dart';

import '../models/enemy.dart';
import '../models/level_node.dart' show Difficulty;
import '../ui/app_card.dart';
import '../ui/neon_button.dart';
import '../utils/theme.dart';
import 'difficulty_chip.dart';
import 'hp_xp_bar.dart';

class EnemyCard extends StatelessWidget {
  const EnemyCard({super.key, required this.enemy, required this.onFight});

  final Enemy enemy;
  final VoidCallback? onFight;

  @override
  Widget build(BuildContext context) {
    final locked = enemy.locked;
    final defeated = enemy.defeated;
    final color = difficultyColor(enemy.difficulty);
    return Opacity(
      opacity: locked ? 0.6 : 1,
      child: AppCard(
        accent: enemy.engaged ? AppColors.danger : null,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: Icon(
                    locked ? Icons.lock_rounded : (enemy.difficulty == Difficulty.boss ? Icons.local_fire_department_rounded : Icons.pets_rounded),
                    color: color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(enemy.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.display(fontSize: 18)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text('Lv.${enemy.level}', style: AppTheme.mono(fontSize: 12, color: AppColors.textDim)),
                          const SizedBox(width: 8),
                          DifficultyChip(difficulty: enemy.difficulty, compact: true),
                        ],
                      ),
                    ],
                  ),
                ),
                if (defeated)
                  const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24)
                else if (enemy.engaged)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(AppRadius.full)),
                    child: Text('ENGAGED', style: AppTheme.overline(color: AppColors.danger)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            HpXpBar(
              progress: enemy.hpProgress,
              color: defeated ? AppColors.textFaint : AppColors.danger,
              label: 'HP',
              trailing: '${enemy.hpCurrent}/${enemy.hpMax}',
              height: 6,
            ),
            const SizedBox(height: 12),
            if (enemy.vulnerability.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.topic_rounded, size: 15, color: AppColors.textFaint),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Topic: ${enemy.vulnerability}', style: const TextStyle(fontSize: 13, color: AppColors.textDim))),
                ],
              ),
            const SizedBox(height: 14),
            if (locked)
              Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 15, color: AppColors.textFaint),
                  const SizedBox(width: 6),
                  Expanded(child: Text(enemy.unlockHint.isEmpty ? 'Locked' : enemy.unlockHint, style: const TextStyle(fontSize: 12, color: AppColors.textFaint))),
                ],
              )
            else
              Row(
                children: [
                  const Icon(Icons.bolt_rounded, size: 16, color: AppColors.accent),
                  Text(' +${enemy.xpReward} XP', style: AppTheme.mono(fontSize: 12, color: AppColors.accent)),
                  const SizedBox(width: 12),
                  const Icon(Icons.monetization_on_rounded, size: 16, color: AppColors.gold),
                  Text(' +${enemy.goldReward}', style: AppTheme.mono(fontSize: 12, color: AppColors.gold)),
                  const Spacer(),
                  NeonButton(
                    label: defeated ? 'Rematch' : 'Fight',
                    compact: true,
                    expanded: false,
                    variant: defeated ? NeonVariant.secondary : NeonVariant.primary,
                    onPressed: onFight,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
