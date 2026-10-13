// Shared UI building blocks, following Apple's fluid-interface principles:
// instant press feedback, critically-damped springs, translucent chrome,
// meaningful-only haptics, and respect for reduced-motion settings.
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

/// Critically damped spring (damping ratio 1.0, response ~0.35s): no overshoot.
final SpringDescription kSpring = SpringDescription.withDampingRatio(
  mass: 1,
  stiffness: 320, // (2π / 0.35)² ≈ 322
  ratio: 1.0,
);

/// Shared app-wide scroll feel: soft rubber-band at the edges.
const kScrollPhysics = BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Haptics only for meaningful moments (selection change, commit).
class Haptics {
  static void select() => HapticFeedback.selectionClick();
  static void commit() => HapticFeedback.lightImpact();
}

/// Scales down on pointer-down (not on release) and springs back from the
/// current value, so the press can be interrupted at any moment.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.pressedScale = 0.97});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(vsync: this, value: 1);

  void _to(double target) {
    if (reduceMotion(context)) {
      _c.value = target;
      return;
    }
    // Start from the live (presentation) value and current velocity.
    _c.animateWith(SpringSimulation(kSpring, _c.value, target, _c.velocity));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _to(widget.pressedScale),
      onPointerUp: (_) => _to(1),
      onPointerCancel: (_) => _to(1),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) => Transform.scale(scale: _c.value, child: child),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Translucent material: blurred backdrop with a semi-transparent tint.
/// Falls back to a solid surface when the user asks for high contrast.
class Glass extends StatelessWidget {
  final Widget child;
  final double blur;
  const Glass({super.key, required this.child, this.blur = 24});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    if (highContrast) {
      return ColoredBox(color: cs.surface, child: child);
    }
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: ColoredBox(color: cs.surface.withValues(alpha: 0.72), child: child),
      ),
    );
  }
}

/// Size-specific tracking: tighten large display text, leave body alone.
TextStyle display(BuildContext context, double size, {Color? color, FontWeight weight = FontWeight.w800}) =>
    TextStyle(
      fontSize: size,
      fontWeight: weight,
      height: 1.05,
      letterSpacing: -0.02 * size,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );

/// A short, critically damped route transition (cross-fade when motion is reduced).
class FluidRoute<T> extends PageRouteBuilder<T> {
  FluidRoute({required WidgetBuilder builder})
      : super(
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (context, _, __) => builder(context),
          transitionsBuilder: (context, anim, secondary, child) {
            if (reduceMotion(context)) return FadeTransition(opacity: anim, child: child);
            // Enter and exit along the same path (mirrored for RTL).
            final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
            final rtl = Directionality.of(context) == TextDirection.rtl;
            return SlideTransition(
              position: Tween(begin: Offset(rtl ? -1 : 1, 0), end: Offset.zero).animate(curve),
              child: child,
            );
          },
        );
}

/// Staggered entrance: fade + small rise, delayed by list position.
/// Only the first screenful animates; reduced-motion users get no motion.
class Appear extends StatefulWidget {
  final int index;
  final Widget child;
  const Appear({super.key, required this.index, required this.child});

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotion(context) || widget.index > 8) {
      _c.value = 1;
    } else {
      Future.delayed(Duration(milliseconds: 40 * widget.index), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curve,
      child: AnimatedBuilder(
        animation: curve,
        builder: (_, child) => Transform.translate(offset: Offset(0, 14 * (1 - curve.value)), child: child),
        child: widget.child,
      ),
    );
  }
}
