import 'package:flutter/material.dart';
import '../models/level_node.dart';
import '../utils/theme.dart';

Color difficultyColor(Difficulty d) {
  switch (d) {
    case Difficulty.easy:
      return AppColors.secondary;
    case Difficulty.medium:
      return AppColors.tertiary;
    case Difficulty.hard:
      return AppColors.error;
    case Difficulty.boss:
      return AppColors.primary;
  }
}

class DifficultyChip extends StatelessWidget {
  const DifficultyChip({super.key, required this.difficulty, this.compact = false});

  final Difficulty difficulty;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = difficultyColor(difficulty);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 3 : 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        difficultyLabel(difficulty).toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5),
      ),
    );
  }
}

/// Filter bar: All / Easy / Medium / Hard / Boss chips.
class DifficultyFilterBar extends StatelessWidget {
  const DifficultyFilterBar({super.key, required this.selected, required this.onSelected});

  final Difficulty? selected; // null = All
  final ValueChanged<Difficulty?> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = <Difficulty?>[null, ...Difficulty.values];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = options[i];
          final isSelected = d == selected;
          final label = d == null ? 'All' : difficultyLabel(d);
          final color = d == null ? AppColors.primary : difficultyColor(d);
          return ChoiceChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (_) => onSelected(d),
            selectedColor: color.withValues(alpha: 0.25),
            backgroundColor: AppColors.surfaceContainerHigh,
            labelStyle: TextStyle(
              color: isSelected ? color : AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            side: BorderSide(color: isSelected ? color : AppColors.outlineVariant),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
          );
        },
      ),
    );
  }
}
