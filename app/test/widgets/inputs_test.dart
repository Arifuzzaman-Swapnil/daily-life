import 'package:dailylife/core/theme/dl_tokens.dart';
import 'package:dailylife/core/widgets/dl_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  testWidgets('DLTextField: label, optional suffix, hint, 52 tall, accent focus border', (tester) async {
    String? typed;
    await pumpDL(
      tester,
      DLTextField(label: 'অতিরিক্ত নোট', optionalLabel: bn.optional, hint: 'যা মনে রাখতে চান', onChanged: (v) => typed = v),
    );
    final c = colorsOf(tester);
    expect(find.textContaining('অতিরিক্ত নোট', findRichText: true), findsOneWidget);
    expect(find.textContaining('(${bn.optional})', findRichText: true), findsOneWidget);
    expect(find.text('যা মনে রাখতে চান'), findsOneWidget);
    expect(tester.getSize(find.byType(TextField)).height, greaterThanOrEqualTo(DLSize.controlLg));

    final deco = tester.widget<TextField>(find.byType(TextField)).decoration!;
    expect(deco.fillColor, c.surface);
    expect((deco.enabledBorder! as OutlineInputBorder).borderSide, BorderSide(color: c.borderStrong));
    expect((deco.focusedBorder! as OutlineInputBorder).borderSide, BorderSide(color: c.accent, width: 2));
    expect((deco.enabledBorder! as OutlineInputBorder).borderRadius, const BorderRadius.all(Radius.circular(DLRadius.md)));

    await tester.enterText(find.byType(TextField), 'বাজার');
    expect(typed, 'বাজার');
  });

  testWidgets('DLTextField error: 2px danger border and an alert line under the field', (tester) async {
    await pumpDL(tester, const DLTextField(label: 'পরিমাণ (৳)', amount: true, hint: '০', error: 'সঠিক পরিমাণ লিখুন'));
    final c = colorsOf(tester);
    final deco = tester.widget<TextField>(find.byType(TextField)).decoration!;
    expect((deco.enabledBorder! as OutlineInputBorder).borderSide, BorderSide(color: c.danger, width: 2));
    expect((deco.focusedBorder! as OutlineInputBorder).borderSide, BorderSide(color: c.danger, width: 2));
    expect(find.text('সঠিক পরিমাণ লিখুন'), findsOneWidget);
    expect(styleOf(tester, 'সঠিক পরিমাণ লিখুন').color, c.dangerText);
    expect(tester.widget<Icon>(find.byIcon(DLIcons.alert)).color, c.dangerText);
    expect(tester.getTopLeft(find.byType(DLErrorText)).dy, greaterThan(tester.getBottomLeft(find.byType(TextField)).dy));
    // The amount field is the 64-tall `.amt` with the amountLg style.
    expect(tester.getSize(find.byType(TextField)).height, greaterThanOrEqualTo(64));
    expect(tester.widget<TextField>(find.byType(TextField)).style!.fontSize, DLText.amountLg.fontSize);
  });

  testWidgets('DLTextField multiline is at least 104 tall', (tester) async {
    await pumpDL(tester, const DLTextField(label: 'বিবরণ', multiline: true, hint: 'বিস্তারিত লিখুন'));
    expect(tester.getSize(find.byType(TextField)).height, greaterThanOrEqualTo(104));
  });

  testWidgets('DLSelect opens a dropdown, marks the current option and reports the pick', (tester) async {
    String? picked;
    await pumpDL(
      tester,
      DLSelect<String>(
        label: 'পেমেন্ট পদ্ধতি',
        value: 'cash',
        options: const [('cash', 'নগদ টাকা'), ('bkash', 'বিকাশ'), ('bank', 'ব্যাংক ট্রান্সফার')],
        onChanged: (v) => picked = v,
      ),
    );
    final c = colorsOf(tester);
    expect(find.text('নগদ টাকা'), findsOneWidget);
    expect(find.text('বিকাশ'), findsNothing);
    expect(tester.getSize(find.byType(DLPressable).first).height, DLSize.controlLg);
    expect(find.byIcon(DLIcons.chevronDown), findsOneWidget);

    await tester.tap(find.text('নগদ টাকা'));
    await tester.pumpAndSettle();
    expect(find.text('বিকাশ'), findsOneWidget);
    expect(find.text('নগদ টাকা'), findsNWidgets(2), reason: 'field + menu item');
    expect(find.byIcon(DLIcons.check), findsOneWidget, reason: 'the current option is checked');
    // The menu opens below the field.
    expect(tester.getTopLeft(find.text('বিকাশ')).dy, greaterThan(tester.getBottomLeft(find.byType(DLSelect<String>)).dy - 16));
    final selected = tester.widget<AnimatedContainer>(find.ancestor(of: find.text('নগদ টাকা').last, matching: find.byType(AnimatedContainer)).first);
    expect((selected.decoration! as BoxDecoration).color, c.accentSoft);

    await tester.tap(find.text('বিকাশ'));
    await tester.pumpAndSettle();
    expect(picked, 'bkash');
    expect(find.text('বিকাশ'), findsNothing, reason: 'menu closed');

    // Tapping outside closes the menu without a change.
    picked = null;
    await tester.tap(find.text('নগদ টাকা'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(200, 800));
    await tester.pumpAndSettle();
    expect(find.text('বিকাশ'), findsNothing);
    expect(picked, isNull);
  });

  testWidgets('DLSelect shows its hint and error', (tester) async {
    await pumpDL(
      tester,
      DLSelect<String>(value: null, hint: 'বেছে নিন', error: 'একটি খাত বেছে নিন', options: const [('a', 'ক')], onChanged: (_) {}),
    );
    final c = colorsOf(tester);
    expect(styleOf(tester, 'বেছে নিন').color, c.textSecondary);
    expect(find.text('একটি খাত বেছে নিন'), findsOneWidget);
  });

  testWidgets('DLSwitch and DLCheckbox toggle, report state and use the prototype colours', (tester) async {
    final semantics = tester.ensureSemantics();
    var on = false;
    var done = false;
    await pumpDL(
      tester,
      StatefulBuilder(
        builder: (context, setState) => Row(
          children: [
            DLSwitch(value: on, semanticLabel: 'বাংলা তারিখ', onChanged: (v) => setState(() => on = v)),
            DLCheckbox(value: done, semanticLabel: 'সম্পন্ন', onChanged: (v) => setState(() => done = v)),
          ],
        ),
      ),
    );
    final c = colorsOf(tester);
    BoxDecoration track() => groundOf(tester, find.byType(DLSwitch));
    expect(tester.getSize(find.byType(DLSwitch)), const Size(52, 48));
    expect(tester.getSize(find.byType(DLCheckbox)), const Size.square(48));
    expect(track().color, c.borderStrong);
    bool? toggled() => tester.widget<Semantics>(find.descendant(of: find.byType(DLSwitch), matching: find.byType(Semantics)).first).properties.toggled;
    expect(tester.getSemantics(find.byType(DLSwitch)), containsSemantics(label: 'বাংলা তারিখ', isButton: true));
    expect(toggled(), isFalse);

    await tester.tap(find.byType(DLSwitch));
    await tester.pumpAndSettle();
    expect(on, isTrue);
    expect(track().color, c.actionPrimary);
    expect(toggled(), isTrue);

    expect(find.byIcon(DLIcons.check), findsNothing);
    await tester.tap(find.byType(DLCheckbox));
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(find.byIcon(DLIcons.check), findsOneWidget);
    expect(groundOf(tester, find.byType(DLCheckbox)).color, c.success);
    semantics.dispose();
  });

  testWidgets('DLSwitch knob is dark on the bright dark-theme track', (tester) async {
    await pumpDL(tester, DLSwitch(value: true, onChanged: (_) {}), dark: true);
    final knob = tester.widgetList<AnimatedContainer>(find.descendant(of: find.byType(DLSwitch), matching: find.byType(AnimatedContainer))).last;
    expect((knob.decoration! as BoxDecoration).color, DLColors.dark.onActionPrimary);
    expect(groundOf(tester, find.byType(DLSwitch)).color, DLColors.dark.actionPrimary);
  });

  testWidgets('DLSearchBar shows a clear button once there is text', (tester) async {
    final changes = <String>[];
    await pumpDL(tester, DLSearchBar(hint: 'লেনদেন খুঁজুন', onChanged: changes.add));
    expect(tester.getSize(find.byType(DLSearchBar)).height, DLSize.touch);
    expect(find.byTooltip(bn.reset), findsNothing);
    await tester.enterText(find.byType(TextField), 'খাবার');
    await tester.pump();
    expect(find.byTooltip(bn.reset), findsOneWidget);
    await tester.tap(find.byTooltip(bn.reset));
    await tester.pump();
    expect(find.text('খাবার'), findsNothing);
    expect(changes.last, '');
    expect(find.byTooltip(bn.reset), findsNothing);
  });
}
