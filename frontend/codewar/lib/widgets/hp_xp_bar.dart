import 'package:flutter/material.dart';
import '../utils/theme.dart';

class HpXpBar extends StatelessWidget {
  const HpXpBar({
    super.key,
    required this.progress,
    required this.color,
    this.label,
    this.trailing,
    this.height = 8,
  });

  final double progress;
  final Color color;
  final String? label;
  final String? trailing;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null || trailing != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (label != null)
                  Text(
                    label!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                if (trailing != null)
                  Text(trailing!, style: AppTheme.mono(fontSize: 11, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: progress.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: height,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }
}
