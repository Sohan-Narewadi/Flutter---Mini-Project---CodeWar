import 'package:flutter/material.dart';

import '../utils/theme.dart';

/// A softly pulsing placeholder block shown while data loads, instead of
/// flashing fake or empty content.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.height = 16, this.width, this.radius = AppRadius.lg});

  final double height;
  final double? width;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: Color.lerp(AppColors.surfaceContainer, AppColors.surfaceContainerHighest, _c.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// A list of skeleton rows used while a screen's first load is in flight.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.rows = 4, this.rowHeight = 72});
  final int rows;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('skeletonList'),
      children: [
        for (var i = 0; i < rows; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SkeletonBox(height: rowHeight, radius: AppRadius.xl),
          ),
      ],
    );
  }
}
