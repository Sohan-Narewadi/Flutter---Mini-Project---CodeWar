import 'package:flutter/material.dart';
import '../models/level_node.dart';
import '../utils/theme.dart';
import 'difficulty_chip.dart';

/// A single node in the World Map's linear sector spine.
class SectorTile extends StatelessWidget {
  const SectorTile({super.key, required this.node, this.onTap, required this.isLast});

  final LevelNode node;
  final VoidCallback? onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final locked = node.status == NodeStatus.locked;
    final current = node.status == NodeStatus.current;
    final done = node.status == NodeStatus.done;

    Color dotColor;
    IconData dotIcon;
    if (done) {
      dotColor = AppColors.secondary;
      dotIcon = Icons.check;
    } else if (current) {
      dotColor = AppColors.primary;
      dotIcon = Icons.bolt;
    } else {
      dotColor = AppColors.outline;
      dotIcon = Icons.lock;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor.withValues(alpha: 0.2),
                  border: Border.all(color: dotColor, width: 2),
                ),
                child: Icon(dotIcon, size: 16, color: dotColor),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: AppColors.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Opacity(
              opacity: locked ? 0.55 : 1,
              child: InkWell(
                onTap: locked ? null : onTap,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: current ? AppColors.surfaceContainerHigh : AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: current ? AppColors.primary : AppColors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${node.order.toString().padLeft(2, '0')} · ${node.name}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.onSurface),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                DifficultyChip(difficulty: node.difficulty, compact: true),
                                const SizedBox(width: 8),
                                if (done)
                                  Row(
                                    children: List.generate(
                                      3,
                                      (i) => Icon(
                                        Icons.star,
                                        size: 13,
                                        color: i < node.stars ? AppColors.tertiary : AppColors.outlineVariant,
                                      ),
                                    ),
                                  )
                                else if (current)
                                  Text('+${node.xpReward} XP · +${node.goldReward} coins',
                                      style: AppTheme.mono(fontSize: 11, color: AppColors.secondary)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (current)
                        const Icon(Icons.chevron_right, color: AppColors.primary)
                      else if (locked)
                        const Icon(Icons.lock_outline, color: AppColors.outline, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
