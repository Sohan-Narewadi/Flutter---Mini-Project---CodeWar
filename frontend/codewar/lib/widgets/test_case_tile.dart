import 'package:flutter/material.dart';
import '../models/battle.dart';
import '../utils/theme.dart';

class TestCaseTile extends StatelessWidget {
  const TestCaseTile({super.key, required this.index, required this.result});

  final int index;
  final TestResult result;

  @override
  Widget build(BuildContext context) {
    final color = result.passed ? AppColors.accent : AppColors.danger;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.passed ? Icons.check_circle : Icons.cancel,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                'Test Case ${index + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const Spacer(),
              Text(
                '${result.durationMs}ms',
                style: AppTheme.mono(fontSize: 11, color: AppColors.textDim),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Input: ${result.input}',
            style: AppTheme.mono(fontSize: 11, color: AppColors.textDim),
          ),
          if (!result.passed) ...[
            const SizedBox(height: 4),
            Text(
              'Expected: ${result.expected}, Got: ${result.actual}',
              style: AppTheme.mono(fontSize: 11, color: AppColors.danger),
            ),
          ],
        ],
      ),
    );
  }
}
