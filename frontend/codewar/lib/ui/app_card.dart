import 'package:flutter/material.dart';

import '../utils/theme.dart';

/// The one card style used across the app: rounded surface, hairline border,
/// optional accent border/glow and tap ripple.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.accent,
    this.onTap,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  /// When set, the border uses this color and a soft glow is added.
  final Color? accent;
  final VoidCallback? onTap;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.xl);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? AppColors.surfaceContainer : null,
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(color: accent ?? AppColors.outlineVariant, width: accent == null ? 1 : 1.5),
        boxShadow: accent == null
            ? null
            : [BoxShadow(color: accent!.withValues(alpha: 0.18), blurRadius: 18, spreadRadius: 0)],
      ),
      child: child,
    );
    final tappable = onTap == null
        ? content
        : Material(
            color: Colors.transparent,
            child: InkWell(borderRadius: radius, onTap: onTap, child: content),
          );
    return margin == null ? tappable : Padding(padding: margin!, child: tappable);
  }
}

/// Section heading with an optional trailing widget.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.onSurface, letterSpacing: 0.2)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
