import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shakes [child] briefly whenever [trigger] decreases (e.g. an enemy took
/// damage and its HP went down).
class ShakeOnDecrease extends StatefulWidget {
  const ShakeOnDecrease({
    super.key,
    required this.trigger,
    required this.child,
  });

  final num trigger;
  final Widget child;

  @override
  State<ShakeOnDecrease> createState() => _ShakeOnDecreaseState();
}

class _ShakeOnDecreaseState extends State<ShakeOnDecrease>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(ShakeOnDecrease old) {
    super.didUpdateWidget(old);
    if (widget.trigger < old.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final decay = 1 - _c.value;
        final dx = math.sin(_c.value * math.pi * 8) * 7 * decay;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}
