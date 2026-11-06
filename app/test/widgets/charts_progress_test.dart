import 'package:dailylife/core/theme/dl_tokens.dart';
import 'package:dailylife/core/widgets/dl_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/// The 10px bars of a [DLBarChart], in paint order.
Finder bars() => find.byWidgetPredicate((w) => w is AnimatedContainer && w.constraints?.maxWidth == DLBarChart.barWidth);

void main() {
  testWidgets('DLBarChart: bars scale to the largest value, series use chart colours, groups are selectable', (tester) async {
    final semantics = tester.ensureSemantics();
    var selected = 1;
    await pumpDL(
      tester,
      StatefulBuilder(
        builder: (context, setState) => DLBarChart(
          selectedIndex: selected,
          onSelect: (i) => setState(() => selected = i),
          groups: const [
            DLBarGroup(label: 'অক্টো', values: [100, 50], semanticLabel: 'অক্টোবর: আয় ১০০, খরচ ৫০'),
            DLBarGroup(label: 'নভে', values: [40, 0], semanticLabel: 'নভেম্বর: আয় ৪০, খরচ ০'),
          ],
        ),
      ),
    );
    final c = colorsOf(tester);
    // 150 plot − 8 top padding − 1px baseline = 141 for the tallest bar.
    final sizes = tester.widgetList(bars()).map((w) => tester.getSize(find.byWidget(w))).toList();
    expect(sizes.map((s) => s.height), [141, 70.5, 56.4, 0]);
    expect(sizes.every((s) => s.width == 10), isTrue);
    final colors = tester.widgetList<AnimatedContainer>(bars()).map((w) => (w.decoration! as BoxDecoration).color).toList();
    expect(colors, [c.chart1, c.chart2, c.chart1, c.chart2]);
    expect(find.text('অক্টো'), findsOneWidget);
    expect(styleOf(tester, 'নভে').color, c.textSecondary);

    BoxDecoration group(int i) => groundOf(tester, find.bySemanticsLabel(i == 0 ? 'অক্টোবর: আয় ১০০, খরচ ৫০' : 'নভেম্বর: আয় ৪০, খরচ ০'));
    expect(group(1).color, c.surfaceSunken);
    expect(group(0).color, c.surfaceSunken.withValues(alpha: 0));

    await tester.tap(find.bySemanticsLabel('অক্টোবর: আয় ১০০, খরচ ৫০'));
    await tester.pumpAndSettle();
    expect(selected, 0);
    expect(group(0).color, c.surfaceSunken);
    semantics.dispose();
  });

  testWidgets('DLBarChart: bars narrow to fit 12 two-bar groups on a 360dp phone', (tester) async {
    await pumpDL(
      tester,
      width: 360,
      DLBarChart(groups: [for (var i = 0; i < 12; i++) DLBarGroup(label: '', values: [100, 50])]),
    );
    expect(tester.takeException(), isNull);
    final widths = [
      for (final w in tester.widgetList<AnimatedContainer>(find.byWidgetPredicate((w) => w is AnimatedContainer && w.child == null)))
        tester.getSize(find.byWidget(w)).width,
    ];
    expect(widths, hasLength(24));
    expect(widths.every((w) => w > 0 && w < DLBarChart.barWidth), isTrue);
  });

  testWidgets('DLBarChart copes with all-zero data and value labels', (tester) async {
    await pumpDL(
      tester,
      const DLBarChart(
        height: 120,
        barAreaHeight: 80,
        groups: [
          DLBarGroup(label: 'শনি', values: [0], valueLabel: '০'),
          DLBarGroup(label: 'রবি', values: [0], valueLabel: '০'),
        ],
      ),
    );
    expect(tester.widgetList(bars()).map((w) => tester.getSize(find.byWidget(w)).height), [0, 0]);
    expect(find.text('০'), findsNWidgets(2));
  });

  testWidgets('DLDonut and DLChartLegend', (tester) async {
    await pumpDL(
      tester,
      const Column(
        children: [
          DLDonut(
            segments: [DLDonutSegment(value: 60, color: Color(0xFF3B82F6)), DLDonutSegment(value: 40, color: Color(0xFF172554))],
            child: Text('৳২২,৮৮০', style: DLText.amountSm),
          ),
          DLDonut(segments: []),
          DLChartLegend(items: [(Color(0xFF3B82F6), 'আয়'), (Color(0xFF172554), 'খরচ')]),
        ],
      ),
    );
    expect(tester.getSize(find.byType(DLDonut).first), const Size.square(132));
    expect(find.text('৳২২,৮৮০'), findsOneWidget);
    expect(tester.getCenter(find.text('৳২২,৮৮০')), tester.getCenter(find.byType(DLDonut).first));
    expect(find.byType(DLDot), findsNWidgets(2));
    expect(find.text('খরচ'), findsOneWidget);
  });

  testWidgets('DLProgressBar: clamps, tone colour, animates width', (tester) async {
    await pumpDL(
      tester,
      const Column(
        children: [
          DLProgressBar(value: 0.5),
          SizedBox(height: 8),
          DLProgressBar(value: 1.4, tone: DLTone.danger, height: 12),
          SizedBox(height: 8),
          DLProgressBar(value: double.nan, tone: DLTone.warning, height: 6),
        ],
      ),
    );
    final c = colorsOf(tester);
    Finder fill(int i) => find.descendant(of: find.byType(DLProgressBar).at(i), matching: find.byType(DecoratedBox)).last;
    final track = tester.getSize(find.byType(DLProgressBar).first);
    expect(track.height, 8);
    expect(tester.getSize(fill(0)).width, track.width / 2);
    expect(tester.getSize(fill(1)).width, track.width);
    expect(tester.getSize(find.byType(DLProgressBar).at(1)).height, 12);
    expect(tester.getSize(fill(2)).width, 0);
    expect((tester.widget<DecoratedBox>(fill(0)).decoration as BoxDecoration).color, c.accent);
    expect((tester.widget<DecoratedBox>(fill(1)).decoration as BoxDecoration).color, c.danger);
  });

  testWidgets('DLProgressRing sizes and centres its content', (tester) async {
    await pumpDL(tester, const Center(child: DLProgressRing(value: 0.4, size: 240, radius: 104, child: Text('০২:১৫'))));
    expect(tester.getSize(find.byType(DLProgressRing)), const Size.square(240));
    expect(tester.getCenter(find.text('০২:১৫')), tester.getCenter(find.byType(DLProgressRing)));
  });

  testWidgets('DLSkeleton pulses, and holds still with reduced motion', (tester) async {
    await pumpDL(tester, const DLSkeleton(height: 84), settle: false);
    double opacity() => tester.widget<Opacity>(find.descendant(of: find.byType(DLSkeleton), matching: find.byType(Opacity))).opacity;
    expect(tester.getSize(find.byType(DLSkeleton)).height, 84);
    expect(opacity(), 1);
    await tester.pump(const Duration(milliseconds: 600));
    expect(opacity(), closeTo(0.5, 0.01));

    await pumpDL(tester, const DLSkeleton(height: 84), reduceMotion: true);
    expect(opacity(), 1);
  });
}
