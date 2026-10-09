import 'package:flutter/material.dart';

import '../utils/theme.dart';

/// The one card style used across the app. Plain by default; pass [accent]
/// for a highlighted card (colored border + soft glow) and [onTap] to make it
/// tappable with a ripple.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.accent,
    this.onTap,
    this.gradient,
    this.flat = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  /// When set, the border uses this color and a soft glow is added.
  final Color? accent;
  final VoidCallback? onTap;
  final Gradient? gradient;

  /// Flat cards have no border (for nesting inside another card).
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.xl);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null
            ? (flat ? AppColors.surfaceHigh : AppColors.surface)
            : null,
        gradient: gradient,
        borderRadius: radius,
        border: flat
            ? null
            : Border.all(
                color: accent == null
                    ? AppColors.line
                    : accent!.withValues(alpha: 0.7),
                width: accent == null ? 1 : 1.5,
              ),
        boxShadow: accent == null
            ? null
            : [
                BoxShadow(
                  color: accent!.withValues(alpha: 0.16),
                  blurRadius: 24,
                  spreadRadius: 0,
                ),
              ],
      ),
      child: child,
    );
    final tappable = onTap == null
        ? content
        : Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: InkWell(borderRadius: radius, onTap: onTap, child: content),
          );
    return margin == null
        ? tappable
        : Padding(padding: margin!, child: tappable);
  }
}

/// Alias used by new code.
typedef GlowCard = AppCard;

/// Section heading: small caps overline with an optional trailing widget.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        children: [
          Expanded(child: Text(text.toUpperCase(), style: AppTheme.overline())),
          ?trailing,
        ],
      ),
    );
  }
}
