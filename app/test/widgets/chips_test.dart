import 'package:dailylife/core/theme/dl_tokens.dart';
import 'package:dailylife/core/widgets/dl_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  testWidgets('DLChip: 40 drawn / 48 touch, selected tint, dashed variant, semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    var picked = '';
    await pumpDL(
      tester,
      Wrap(
        spacing: 8,
        children: [
          DLChip(label: 'খাবার', icon: DLIcons.wallet, selected: true, onTap: () => picked = 'food'),
          DLChip(label: 'যাতায়াত', onTap: () => picked = 'transport'),
          DLChip(label: 'নতুন ক্যাটাগরি', icon: DLIcons.plus, dashed: true, onTap: () {}),
          DLChip(label: 'খাবার ✕', trailingIcon: DLIcons.close, selected: true, semanticLabel: 'ফিল্টার সরান: খাবার', onTap: () {}),
        ],
      ),
    );
    final c = colorsOf(tester);
    Finder chip(String label) => find.widgetWithText(DLChip, label);

    expect(tester.getSize(chip('যাতায়াত')).height, DLSize.touch);
    final pill = tester.getSize(find.descendant(of: chip('যাতায়াত'), matching: find.byType(AnimatedContainer)));
    expect(pill.height, DLChip.height);

    final off = groundOf(tester, chip('যাতায়াত'));
    expect(off.color, c.surface);
    expect((off.border! as Border).top.color, c.divider);
    expect(styleOf(tester, 'যাতায়াত').color, c.textPrimary);

    expect(groundOf(tester, chip('খাবার')).color, c.accentSoft);
    expect(styleOf(tester, 'খাবার').color, c.accentText);
    expect(tester.widget<Icon>(find.byIcon(DLIcons.wallet)).color, c.accentText);

    expect(styleOf(tester, 'নতুন ক্যাটাগরি').color, c.accentText);
    expect(
      find.descendant(of: chip('নতুন ক্যাটাগরি'), matching: find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter is DLDashedBorderPainter)),
      findsOneWidget,
    );

    expect(tester.getSemantics(chip('খাবার')), containsSemantics(isButton: true, isSelected: true, label: 'খাবার'));
    expect(tester.getSemantics(chip('খাবার ✕')), containsSemantics(label: 'ফিল্টার সরান: খাবার'));

    await tester.tap(chip('যাতায়াত'));
    await tester.pump();
    expect(picked, 'transport');
    semantics.dispose();
  });

  testWidgets('DLTag, DLBadge and DLDot use the tone colours', (tester) async {
    await pumpDL(
      tester,
      const Row(
        children: [
          DLTag(label: '+৳৬০,০০০ এ মাসে', tone: DLTone.success),
          DLTag(label: 'জরুরি', tone: DLTone.danger),
          DLBadge('৩'),
          DLDot(color: Color(0xFF3B82F6)),
        ],
      ),
    );
    final c = colorsOf(tester);
    Container box(Type type) => tester.widget<Container>(find.descendant(of: find.byType(type), matching: find.byType(Container)).first);

    final tag = tester.widget<Container>(find.descendant(of: find.widgetWithText(DLTag, 'জরুরি'), matching: find.byType(Container)));
    expect((tag.decoration! as BoxDecoration).color, c.dangerSoft);
    expect(styleOf(tester, 'জরুরি').color, c.dangerText);
    expect(styleOf(tester, '+৳৬০,০০০ এ মাসে').color, c.successText);
    expect(tester.getSize(find.widgetWithText(DLTag, 'জরুরি')).height, 24);
    expect(styleOf(tester, 'জরুরি').fontSize, 12);

    expect((box(DLBadge).decoration! as BoxDecoration).color, c.danger);
    expect(styleOf(tester, '৩').color, c.onDanger);
    expect(tester.getSize(find.byType(DLBadge)).width, greaterThanOrEqualTo(20));
    expect(tester.getSize(find.byType(DLDot)), const Size.square(8));
  });

  testWidgets('DLSegmentedTabs: raised selected segment, taps change value, compact hugs labels', (tester) async {
    final semantics = tester.ensureSemantics();
    var period = 6;
    await pumpDL(
      tester,
      StatefulBuilder(
        builder: (context, setState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DLSegmentedTabs<String>(value: 'inc', options: const [('inc', 'আয়'), ('exp', 'খরচ')], onChanged: (_) {}),
            const SizedBox(height: 12),
            DLSegmentedTabs<int>(
              value: period,
              expand: false,
              options: const [(6, '৬ মাস'), (12, '১২ মাস')],
              onChanged: (v) => setState(() => period = v),
            ),
          ],
        ),
      ),
    );
    final c = colorsOf(tester);
    final full = find.byType(DLSegmentedTabs<String>);
    final compact = find.byType(DLSegmentedTabs<int>);
    expect(tester.getSize(full), const Size(393 - 32, 48));
    expect(tester.getSize(compact).width, lessThan(300));
    final well = tester.widget<DecoratedBox>(find.descendant(of: full, matching: find.byType(DecoratedBox)).first);
    expect((well.decoration as BoxDecoration).color, c.surfaceSunken);

    BoxDecoration segment(String label) =>
        tester.widget<AnimatedContainer>(find.ancestor(of: find.text(label), matching: find.byType(AnimatedContainer)).first).decoration! as BoxDecoration;
    expect(segment('আয়').color, c.surfaceRaised);
    expect(segment('আয়').boxShadow, DLShadows.card(Brightness.light));
    expect(segment('খরচ').boxShadow, isEmpty);
    expect(styleOf(tester, 'আয়').color, c.textPrimary);
    expect(styleOf(tester, 'খরচ').color, c.textSecondary);
    expect(tester.getSemantics(find.text('আয়')), containsSemantics(isSelected: true, isButton: true));

    await tester.tap(find.text('১২ মাস'));
    await tester.pumpAndSettle();
    expect(period, 12);
    expect(segment('১২ মাস').color, c.surfaceRaised);
    expect(styleOf(tester, '৬ মাস').color, c.textSecondary);
    semantics.dispose();
  });
}
