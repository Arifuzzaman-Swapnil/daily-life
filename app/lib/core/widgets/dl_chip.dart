import 'package:flutter/material.dart';

import '../theme/dl_tokens.dart';
import 'dl_motion.dart';
import 'dl_tone.dart';

/// Pill chip (prototype `.chip`): 40 tall, `surface` with a `divider` hairline;
/// selected chips take `accentSoft` with `accentText` and no border.
/// `dashed` is the "+ new category" chip: dashed `borderStrong`, `accentText`.
///
/// The chip is drawn 40 tall but lays out 48 tall (4 above and below) so the
/// whole touch target is 48dp. In a `Wrap`, use `spacing: 8, runSpacing: 0` to
/// get the prototype's 8px gap between rows.
class DLChip extends StatelessWidget {
  const DLChip({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.icon,
    this.trailingIcon,
    this.dashed = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;

  /// 16px icon before the label (category chips).
  final IconData? icon;

  /// 16px icon after the label (the ✕ on an active filter chip).
  final IconData? trailingIcon;
  final bool dashed;

  /// Replaces the label for screen readers, e.g. "Remove filter: Food".
  final String? semanticLabel;

  static const double height = 40;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    final fg = selected || dashed ? c.accentText : c.textPrimary;
    const shape = BorderRadius.all(Radius.circular(DLRadius.pill));
    Widget pill = AnimatedContainer(
      duration: DLMotion.of(context, DLMotion.fast),
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: selected ? c.accentSoft : c.surface,
        borderRadius: shape,
        // Transparent under the dashed outline so every chip has the same 1px box.
        border: Border.all(color: dashed ? Colors.transparent : (selected ? c.accentSoft : c.divider)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
          Text(label, maxLines: 1, style: DLText.textLabel.copyWith(color: fg)),
          if (trailingIcon != null) ...[const SizedBox(width: 6), Icon(trailingIcon, size: 16, color: fg)],
        ],
      ),
    );
    if (dashed) {
      pill = CustomPaint(foregroundPainter: DLDashedBorderPainter(color: c.borderStrong, borderRadius: shape), child: pill);
    }
    return DLPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: semanticLabel,
      excludeSemantics: semanticLabel != null,
      borderRadius: shape,
      child: SizedBox(height: DLSize.touch, child: Center(widthFactor: 1, child: pill)),
    );
  }
}

/// 1px dashed rounded outline (the prototype's `border-style: dashed`).
class DLDashedBorderPainter extends CustomPainter {
  const DLDashedBorderPainter({required this.color, required this.borderRadius, this.dash = 4, this.gap = 3});

  final Color color;
  final BorderRadius borderRadius;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = borderRadius.toRRect(Offset.zero & size).deflate(0.5);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DLDashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.borderRadius != borderRadius || oldDelegate.dash != dash || oldDelegate.gap != gap;
}

/// Small status pill (prototype `.tag`): 24 tall, `textCaption`, a tone's soft
/// fill with its text colour. [background]/[foreground] override the tone, e.g.
/// `brandHover` / `onBrandAccent` on the navy hero.
class DLTag extends StatelessWidget {
  const DLTag({super.key, required this.label, this.tone = DLTone.accent, this.icon, this.background, this.foreground});

  final String label;
  final DLTone tone;
  final IconData? icon;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    final fg = foreground ?? tone.text(c);
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: background ?? tone.soft(c),
        borderRadius: const BorderRadius.all(Radius.circular(DLRadius.pill)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: DLSpace.s1)],
          Text(label, maxLines: 1, style: DLText.textCaption.copyWith(color: fg)),
        ],
      ),
    );
  }
}

/// Count badge (prototype `.badge`): at least 20×20, `danger` fill, `onDanger`
/// 12px semibold text. Pass an already formatted count.
class DLBadge extends StatelessWidget {
  const DLBadge(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.danger, borderRadius: const BorderRadius.all(Radius.circular(DLRadius.pill))),
      child: Text(label, maxLines: 1, style: DLText.textCaption.copyWith(fontWeight: FontWeight.w600, height: 1, color: c.onDanger)),
    );
  }
}

/// Round colour mark (prototype `.dot`): legends, calendar dots, unread marker.
/// [ring] draws a 2px outline in that colour (the unread dot on the bell).
class DLDot extends StatelessWidget {
  const DLDot({super.key, required this.color, this.size = 8, this.ring});

  final Color color;
  final double size;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: ring == null ? null : Border.all(color: ring!, width: 2),
      ),
    );
  }
}
