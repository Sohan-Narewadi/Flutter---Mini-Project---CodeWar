import 'package:flutter/material.dart';

import '../services/sfx.dart';
import '../utils/theme.dart';

enum NeonVariant { primary, secondary, ghost, danger }

/// The one button style used across the app.
///
/// * [NeonVariant.primary]: accent gradient with a soft glow (one per screen).
/// * [NeonVariant.secondary]: outlined.
/// * [NeonVariant.ghost]: text only.
/// * [NeonVariant.danger]: red outline for destructive actions.
class NeonButton extends StatefulWidget {
  const NeonButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = NeonVariant.primary,
    this.loading = false,
    this.expanded = true,
    this.compact = false,
    this.iconOnly = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final NeonVariant variant;

  /// Shows a spinner and ignores taps.
  final bool loading;

  /// Fill the available width (default) or hug the content.
  final bool expanded;
  final bool compact;

  /// Shows only [icon] (the label is still used for accessibility).
  final bool iconOnly;

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton> {
  bool _down = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _fire() {
    Sfx.play(Cue.tap);
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.variant;
    final height = widget.compact ? 44.0 : 54.0;
    final fg = switch (v) {
      NeonVariant.primary => _enabled ? AppColors.onAccent : AppColors.textDim,
      NeonVariant.secondary => AppColors.text,
      NeonVariant.ghost => AppColors.accent,
      NeonVariant.danger => AppColors.danger,
    };
    final border = switch (v) {
      NeonVariant.secondary => Border.all(color: AppColors.line, width: 1.5),
      NeonVariant.danger => Border.all(
        color: AppColors.danger.withValues(alpha: 0.6),
        width: 1.5,
      ),
      _ => null,
    };

    final content = Row(
      mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
          )
        else ...[
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 20, color: fg),
            if (!widget.iconOnly) const SizedBox(width: 8),
          ],
          if (!widget.iconOnly || widget.icon == null)
            Flexible(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.display(
                  fontSize: widget.compact ? 14 : 16,
                  color: fg,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ],
    );

    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      height: height,
      padding: EdgeInsets.symmetric(
        horizontal: widget.iconOnly ? 0 : (widget.compact ? 16 : 22),
      ),
      decoration: BoxDecoration(
        gradient: v == NeonVariant.primary && _enabled
            ? AppColors.accentGradient
            : null,
        color: v == NeonVariant.primary && !_enabled
            ? AppColors.surfaceHighest
            : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: border,
        boxShadow: v == NeonVariant.primary && _enabled
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(
                    alpha: _down ? 0.12 : 0.32,
                  ),
                  blurRadius: _down ? 8 : 22,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: content,
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      excludeSemantics: true,
      onTap: _enabled ? _fire : null,
      child: Opacity(
        opacity: _enabled || widget.loading ? 1 : (v == NeonVariant.primary ? 0.85 : 0.5),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? (_) => setState(() => _down = true) : null,
          onTapCancel: _enabled ? () => setState(() => _down = false) : null,
          onTapUp: _enabled ? (_) => setState(() => _down = false) : null,
          onTap: _enabled ? _fire : null,
          child: AnimatedScale(
            scale: _down ? 0.97 : 1,
            duration: const Duration(milliseconds: 90),
            child: widget.expanded
                ? SizedBox(width: double.infinity, child: box)
                : box,
          ),
        ),
      ),
    );
  }
}
