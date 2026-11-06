import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/dl_tokens.dart';
import 'dl_chip.dart';
import 'dl_motion.dart';

/// One column of [DLBarChart]: a label under the axis and one bar per series.
class DLBarGroup {
  const DLBarGroup({required this.label, required this.values, this.semanticLabel, this.valueLabel});

  /// Axis label, already formatted (may be empty to thin out a long axis).
  final String label;
  final List<double> values;

  /// What a screen reader says for this group, e.g. "নভেম্বর ২০২৬: আয় ৳৫০,০০০, খরচ ৳২২,৮৮০".
  final String? semanticLabel;

  /// Small figure above the bars (the work-hours chart).
  final String? valueLabel;
}

/// Grouped bar chart (prototype `.chart`): groups share the width 6 apart, each
/// series a 10px bar (3 apart, 4px top corners) scaled to [maxValue], a
/// `divider` baseline and `textCaption` labels below. Colours default to
/// `chart1`, `chart2`, … (never the income/expense pair). With [onSelect] the
/// groups are buttons and [selectedIndex] gets the `surfaceSunken` highlight.
class DLBarChart extends StatelessWidget {
  const DLBarChart({
    super.key,
    required this.groups,
    this.colors,
    this.height = 150,
    this.barAreaHeight,
    this.maxValue,
    this.selectedIndex,
    this.onSelect,
    this.semanticLabel,
  });

  final List<DLBarGroup> groups;
  final List<Color>? colors;

  /// Height of the plot above the baseline (prototype: 150, or 120 for small charts).
  final double height;

  /// Fixed bar area under the value labels (prototype work hours: 80); defaults to the full plot.
  final double? barAreaHeight;

  /// Top of the scale; defaults to the largest value.
  final double? maxValue;
  final int? selectedIndex;
  final ValueChanged<int>? onSelect;
  final String? semanticLabel;

  static const double barWidth = 10;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    final palette = colors ?? [c.chart1, c.chart2, c.chart3, c.chart4];
    double top = maxValue ?? 0;
    if (maxValue == null) {
      for (final g in groups) {
        for (final v in g.values) {
          top = math.max(top, v);
        }
      }
    }
    if (top <= 0) top = 1;
    final duration = DLMotion.of(context, DLMotion.progress);

    Widget bars(DLBarGroup g) => LayoutBuilder(
          builder: (context, constraints) {
            final area = constraints.maxHeight;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (i, v) in g.values.indexed) ...[
                  if (i > 0) const SizedBox(width: 3),
                  AnimatedContainer(
                    duration: duration,
                    curve: Curves.ease,
                    width: barWidth,
                    height: area * (v.isNaN ? 0 : v.clamp(0, top)) / top,
                    decoration: BoxDecoration(
                      color: palette[i % palette.length],
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                ],
              ],
            );
          },
        );

    Widget group(int index, DLBarGroup g) {
      final selected = index == selectedIndex;
      const shape = BorderRadius.all(Radius.circular(DLRadius.sm));
      final column = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (g.valueLabel != null)
              Text(g.valueLabel!, maxLines: 1, softWrap: false, style: DLText.textCaption.copyWith(color: c.textSecondary)),
            if (barAreaHeight != null) SizedBox(height: barAreaHeight, child: bars(g)) else Expanded(child: bars(g)),
          ],
        ),
      );
      final decoration = BoxDecoration(color: selected ? c.surfaceSunken : c.surfaceSunken.withValues(alpha: 0), borderRadius: shape);
      if (onSelect == null) {
        return Semantics(
          container: true,
          label: g.semanticLabel,
          child: AnimatedContainer(duration: DLMotion.of(context, DLMotion.fast), decoration: decoration, child: column),
        );
      }
      return DLPressable(
        onTap: () => onSelect!(index),
        selected: selected,
        semanticLabel: g.semanticLabel,
        excludeSemantics: g.semanticLabel != null,
        borderRadius: shape,
        decoration: decoration,
        child: column,
      );
    }

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: height,
            padding: const EdgeInsets.only(top: DLSpace.s2),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.divider))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, g) in groups.indexed) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(child: group(i, g)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          ExcludeSemantics(
            child: Row(
              children: [
                for (final (i, g) in groups.indexed) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      g.label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      textAlign: TextAlign.center,
                      style: DLText.textCaption.copyWith(color: c.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One slice of [DLDonut].
class DLDonutSegment {
  const DLDonutSegment({required this.value, required this.color});

  final double value;
  final Color color;
}

/// Donut chart (the reports' category breakdown): slices drawn clockwise from
/// 12 o'clock with 2px gaps, a 20px ring of radius 52 in a 132 box, and
/// optional content in the middle (caption + total).
class DLDonut extends StatelessWidget {
  const DLDonut({
    super.key,
    required this.segments,
    this.size = 132,
    this.radius = 52,
    this.strokeWidth = 20,
    this.gap = 2,
    this.child,
    this.semanticLabel,
  });

  final List<DLDonutSegment> segments;
  final double size;

  /// Radius of the ring's centre line.
  final double radius;
  final double strokeWidth;

  /// Gap between slices, in px along the ring.
  final double gap;
  final Widget? child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticLabel,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _DonutPainter(segments: segments, radius: radius, strokeWidth: strokeWidth, gap: gap, empty: context.dl.surfaceSunken),
          child: child == null ? null : Center(child: child),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.segments, required this.radius, required this.strokeWidth, required this.gap, required this.empty});

  final List<DLDonutSegment> segments;
  final double radius;
  final double strokeWidth;
  final double gap;

  /// Track shown when every slice is zero.
  final Color empty;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final sum = segments.fold<double>(0, (a, s) => a + math.max(0, s.value));
    if (sum <= 0) {
      canvas.drawCircle(rect.center, radius, paint..color = empty);
      return;
    }
    final gapAngle = gap / radius;
    var start = -math.pi / 2;
    for (final s in segments) {
      final sweep = 2 * math.pi * math.max(0, s.value) / sum;
      final visible = sweep - gapAngle;
      if (visible > 0) {
        paint.color = s.color;
        canvas.drawArc(rect, start, visible, false, paint);
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.segments != segments ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.gap != gap ||
      oldDelegate.empty != empty;
}

/// Chart legend (prototype `.lgd`): 8px dots with `textCaption` labels, 16 apart.
class DLChartLegend extends StatelessWidget {
  const DLChartLegend({super.key, required this.items});

  final List<(Color, String)> items;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    return Wrap(
      spacing: DLSpace.s4,
      runSpacing: DLSpace.s1,
      children: [
        for (final (color, label) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DLDot(color: color),
              const SizedBox(width: 6),
              Flexible(child: Text(label, style: DLText.textCaption.copyWith(color: c.textSecondary))),
            ],
          ),
      ],
    );
  }
}
