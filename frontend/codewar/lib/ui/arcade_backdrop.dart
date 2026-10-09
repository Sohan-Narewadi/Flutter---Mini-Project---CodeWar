import 'package:flutter/material.dart';

import '../utils/theme.dart';

/// Full-bleed page background: deep navy, a faint grid and soft accent glows
/// at the top corners. Purely decorative (excluded from semantics).
class ArcadeBackdrop extends StatelessWidget {
  const ArcadeBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ExcludeSemantics(
          child: RepaintBoundary(child: CustomPaint(painter: _BackdropPainter())),
        ),
        child,
      ],
    );
  }
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.background);

    // Faint grid.
    final grid = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Soft glows (violet top-left, cyan top-right), fading out downward.
    void glow(Offset c, double r, Color color) {
      final rect = Rect.fromCircle(center: c, radius: r);
      canvas.drawCircle(
        c,
        r,
        Paint()..shader = RadialGradient(colors: [color.withValues(alpha: 0.20), color.withValues(alpha: 0)]).createShader(rect),
      );
    }

    glow(Offset(size.width * 0.05, -20), size.width * 0.8, AppColors.accentDeep);
    glow(Offset(size.width * 0.98, 40), size.width * 0.7, AppColors.accent);

    // Fade the grid into the base color toward the bottom so content stays calm.
    final fade = Rect.fromLTWH(0, size.height * 0.35, size.width, size.height * 0.65);
    canvas.drawRect(
      fade,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.background.withValues(alpha: 0), AppColors.background.withValues(alpha: 0.92)],
        ).createShader(fade),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
