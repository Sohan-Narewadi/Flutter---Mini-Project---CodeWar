import 'package:flutter/material.dart';
import '../utils/theme.dart';

class RewardRow extends StatelessWidget {
  const RewardRow({super.key, required this.icon, required this.label, required this.value, this.color});

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.tertiary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: c.withValues(alpha: 0.18), shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: c),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant))),
          Text(value, style: AppTheme.mono(fontSize: 14, fontWeight: FontWeight.w700, color: c)),
        ],
      ),
    );
  }
}
