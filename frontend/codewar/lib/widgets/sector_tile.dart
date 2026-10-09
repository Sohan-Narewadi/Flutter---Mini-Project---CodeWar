import 'package:flutter/material.dart';

import '../models/level_node.dart';
import '../utils/theme.dart';
import 'difficulty_chip.dart';

/// A single node on the campaign path: a status marker on a connector line
/// plus a card with the level name, difficulty and reward/stars.
class SectorTile extends StatelessWidget {
  const SectorTile({
    super.key,
    required this.node,
    this.onTap,
    required this.isLast,
  });

  final LevelNode node;
  final VoidCallback? onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final locked = node.status == NodeStatus.locked;
    final current = node.status == NodeStatus.current;
    final done = node.status == NodeStatus.done;

    final Color dotColor = done
        ? AppColors.success
        : current
        ? AppColors.accent
        : AppColors.textFaint;
    final IconData dotIcon = done
        ? Icons.check_rounded
        : current
        ? Icons.bolt_rounded
        : Icons.lock_rounded;

    return Semantics(
      button: !locked,
      label:
          '${node.name}, ${difficultyLabel(node.difficulty)}, ${locked
              ? 'locked'
              : done
              ? 'completed'
              : 'available'}',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor.withValues(alpha: current ? 0.2 : 0.12),
                      border: Border.all(
                        color: dotColor,
                        width: current ? 2 : 1.5,
                      ),
                      boxShadow: current
                          ? [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.45),
                                blurRadius: 14,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(dotIcon, size: 18, color: dotColor),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(1),
                          color: done
                              ? AppColors.success.withValues(alpha: 0.5)
                              : AppColors.line,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Opacity(
                  opacity: locked ? 0.5 : 1,
                  child: Material(
                    color: current ? AppColors.surfaceHigh : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    child: InkWell(
                      onTap: locked ? null : onTap,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          border: Border.all(
                            color: current
                                ? AppColors.accent.withValues(alpha: 0.7)
                                : AppColors.line,
                            width: current ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'LEVEL ${node.order.toString().padLeft(2, '0')}',
                                    style: AppTheme.overline(
                                      color: current
                                          ? AppColors.accent
                                          : AppColors.textFaint,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    node.name,
                                    style: AppTheme.display(
                                      fontSize: 16,
                                      height: 1.15,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 6,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      DifficultyChip(
                                        difficulty: node.difficulty,
                                        compact: true,
                                      ),
                                      if (done)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: List.generate(
                                            3,
                                            (i) => Icon(
                                              Icons.star_rounded,
                                              size: 16,
                                              color: i < node.stars
                                                  ? AppColors.gold
                                                  : AppColors.line,
                                            ),
                                          ),
                                        )
                                      else if (!locked)
                                        Text(
                                          '+${node.xpReward} XP  ·  +${node.goldReward} gold',
                                          style: AppTheme.mono(
                                            fontSize: 11,
                                            color: AppColors.textDim,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (current)
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: AppColors.accent,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
