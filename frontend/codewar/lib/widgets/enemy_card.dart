import 'package:flutter/material.dart';
import '../models/enemy.dart';
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
    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: enemy.engaged ? AppColors.primary : AppColors.outlineVariant,
            width: enemy.engaged ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: difficultyColor(enemy.difficulty).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Icon(
                    locked ? Icons.lock : (enemy.difficulty.name == 'boss' ? Icons.local_fire_department : Icons.pets),
                    color: difficultyColor(enemy.difficulty),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(enemy.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('Lv.${enemy.level}', style: AppTheme.mono(fontSize: 12, color: AppColors.onSurfaceVariant)),
                          const SizedBox(width: 8),
                          DifficultyChip(difficulty: enemy.difficulty, compact: true),
                        ],
                      ),
                    ],
                  ),
                ),
                if (defeated)
                  const Icon(Icons.check_circle, color: AppColors.secondary, size: 22)
                else if (enemy.engaged)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: const Text('ENGAGED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.error)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            HpXpBar(
              progress: enemy.hpProgress,
              color: defeated ? AppColors.outline : AppColors.error,
              label: 'HP',
              trailing: '${enemy.hpCurrent}/${enemy.hpMax}',
              height: 6,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.gpp_maybe, size: 14, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('Weak: ${enemy.vulnerability}',
                      style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (locked)
              Text(enemy.unlockHint,
                  style: const TextStyle(fontSize: 11, color: AppColors.outline, fontStyle: FontStyle.italic))
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt, size: 14, color: AppColors.secondary),
                      Text(' +${enemy.xpReward} XP', style: AppTheme.mono(fontSize: 11, color: AppColors.secondary)),
                      const SizedBox(width: 10),
                      const Icon(Icons.monetization_on, size: 14, color: AppColors.tertiary),
                      Text(' +${enemy.goldReward}', style: AppTheme.mono(fontSize: 11, color: AppColors.tertiary)),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: onFight,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    child: Text(defeated ? 'Rematch' : 'Fight'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
