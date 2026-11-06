import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/dl_tokens.dart';
import 'dl_motion.dart';
import 'dl_tone.dart';

/// Linear progress (prototype `.trk` / `.bar`): a `surfaceSunken` pill track,
/// 8 tall (`.t6` 6, `.t12` 12), with a pill bar in the tone's solid colour that
/// animates its width over 300 ms. [value] is clamped to 0…1. Fills the width
/// it is given.
class DLProgressBar extends StatelessWidget {
  const DLProgressBar({
    super.key,
    required this.value,
    this.tone = DLTone.accent,
    this.height = 8,
    this.color,
    this.trackColor,
    this.semanticLabel,
    this.semanticValue,
  });

  final double value;
  final DLTone tone;
  final double height;

  /// Bar colour override.
  final Color? color;

  /// Track colour override, e.g. `brandHover` on the navy hero.
  final Color? trackColor;
  final String? semanticLabel;

  /// Formatted value for screen readers, e.g. "৬৫%".
  final String? semanticValue;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    const shape = BorderRadius.all(Radius.circular(DLRadius.pill));
    return Semantics(
      label: semanticLabel,
      value: semanticValue,
      child: Container(
        width: double.infinity,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: trackColor ?? c.surfaceSunken, borderRadius: shape),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: v),
          duration: DLMotion.of(context, DLMotion.progress),
          curve: Curves.ease,
          builder: (context, w, _) => FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: w,
            heightFactor: 1,
            child: DecoratedBox(decoration: BoxDecoration(color: color ?? tone.solid(c), borderRadius: shape)),
          ),
        ),
      ),
    );
  }
}

/// Circular progress (prototype `svg.ring`): a `surfaceSunken` track and a
/// round-capped arc from 12 o'clock, animating over 400 ms. The timer uses
/// size 240 / radius 104, the water ring 184 / 80, both with a 14 stroke.
class DLProgressRing extends StatelessWidget {
  const DLProgressRing({
    super.key,
    required this.value,
    this.size = 184,
    this.strokeWidth = 14,
    this.radius,
    this.color,
    this.child,
    this.semanticLabel,
    this.semanticValue,
  });

  final double value;
  final double size;
  final double strokeWidth;

  /// Radius of the stroke's centre line; defaults to filling [size].
  final double? radius;
  final Color? color;

  /// Content centred in the ring.
  final Widget? child;
  final String? semanticLabel;

  /// Formatted value for screen readers, e.g. "৬৫%".
  final String? semanticValue;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return Semantics(
      label: semanticLabel,
      value: semanticValue,
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: v),
          duration: DLMotion.of(context, DLMotion.ring),
          curve: Curves.ease,
          builder: (context, p, inner) => CustomPaint(
            painter: _RingPainter(
              progress: p,
              track: c.surfaceSunken,
              color: color ?? c.accent,
              strokeWidth: strokeWidth,
              radius: radius ?? (size - strokeWidth) / 2,
            ),
            child: inner,
          ),
          child: child == null ? null : Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.track, required this.color, required this.strokeWidth, required this.radius});

  final double progress;
  final Color track;
  final Color color;
  final double strokeWidth;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(rect.center, radius, paint..color = track);
    if (progress <= 0) return;
    paint
      ..color = color
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.track != track ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.radius != radius;
}

/// Loading placeholder block (prototype `.skel`): `surfaceSunken`, radius 12,
/// pulsing to half opacity every 1.2 s (still when motion is reduced).
class DLSkeleton extends StatefulWidget {
  const DLSkeleton({super.key, required this.height, this.width});

  final double height;
  final double? width;

  @override
  State<DLSkeleton> createState() => _DLSkeletonState();
}

class _DLSkeletonState extends State<DLSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (DLMotion.reduced(context)) {
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(color: context.dl.surfaceSunken, borderRadius: const BorderRadius.all(Radius.circular(DLRadius.md))),
    );
    return AnimatedBuilder(
      animation: _pulse,
      // 1 → 0.5 → 1 (CSS `@keyframes pl { 50% { opacity: .5 } }`).
      builder: (context, child) => Opacity(opacity: 1 - 0.5 * math.sin(math.pi * _pulse.value), child: child),
      child: box,
    );
  }
}
