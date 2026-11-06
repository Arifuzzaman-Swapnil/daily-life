import 'package:dailylife/core/theme/dl_tokens.dart';
import 'package:dailylife/core/widgets/dl_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  testWidgets('DLButton: heights, variants, tap and disabled state', (tester) async {
    var taps = 0;
    await pumpDL(
      tester,
      Column(
        children: [
          DLButton(label: 'সংরক্ষণ করুন', onPressed: () => taps++),
          DLButton(label: 'বাতিল', size: DLButtonSize.md, variant: DLButtonVariant.secondary, onPressed: () {}),
          DLButton(label: 'ছোট', size: DLButtonSize.sm, variant: DLButtonVariant.tonal, onPressed: () {}),
          DLButton(label: 'মুছুন', variant: DLButtonVariant.danger, onPressed: () {}),
          const DLButton(label: 'বন্ধ', onPressed: null),
        ],
      ),
    );
    final c = colorsOf(tester);
    Finder button(String label) => find.widgetWithText(DLButton, label);

    expect(tester.getSize(button('সংরক্ষণ করুন')), const Size(393 - 32, DLSize.controlLg));
    expect(tester.getSize(button('বাতিল')).height, DLSize.controlMd);
    expect(tester.getSize(button('ছোট')).height, DLSize.controlSm);
    expect(tester.getSize(button('ছোট')).width, lessThan(200), reason: 'sm hugs its label');

    expect(groundOf(tester, button('সংরক্ষণ করুন')).color, c.actionPrimary);
    expect(styleOf(tester, 'সংরক্ষণ করুন').color, c.onActionPrimary);
    final secondary = groundOf(tester, button('বাতিল'));
    expect(secondary.color, c.surface);
    expect((secondary.border! as Border).top.color, c.borderStrong);
    expect(styleOf(tester, 'বাতিল').color, c.accentText);
    expect(groundOf(tester, button('ছোট')).color, c.accentSoft);
    expect(groundOf(tester, button('মুছুন')).color, c.danger);
    expect(groundOf(tester, button('বন্ধ')).color, c.surfaceSunken);
    expect(styleOf(tester, 'বন্ধ').color, c.textDisabled);

    await tester.tap(button('সংরক্ষণ করুন'));
    await tester.pump();
    expect(taps, 1);
    await tester.tap(button('বন্ধ'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('DLButton follows the dark theme (bright blue primary, dark label)', (tester) async {
    await pumpDL(tester, DLButton(label: 'সংরক্ষণ করুন', onPressed: () {}), dark: true);
    expect(groundOf(tester, find.byType(DLButton)).color, DLColors.dark.actionPrimary);
    expect(styleOf(tester, 'সংরক্ষণ করুন').color, DLColors.dark.onActionPrimary);
  });

  testWidgets('press scales to 97 % and the scale is instant with reduced motion', (tester) async {
    await pumpDL(tester, DLButton(label: 'চাপুন', onPressed: () {}));
    AnimatedScale scale() => tester.widget<AnimatedScale>(find.descendant(of: find.byType(DLButton), matching: find.byType(AnimatedScale)));
    expect(scale().scale, 1);
    expect(scale().duration, const Duration(milliseconds: 150));
    final gesture = await tester.startGesture(tester.getCenter(find.text('চাপুন')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(scale().scale, 0.97);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(scale().scale, 1);

    await pumpDL(tester, DLButton(label: 'চাপুন', onPressed: () {}), reduceMotion: true);
    expect(scale().duration, Duration.zero);
  });

  testWidgets('DLIconButton: 48dp, tooltip is the label, tonal variant is 44 on accentSoft', (tester) async {
    var taps = 0;
    await pumpDL(
      tester,
      Row(
        children: [
          DLIconButton(icon: DLIcons.gear, tooltip: 'সেটিংস', onPressed: () => taps++),
          DLIconButton(icon: DLIcons.search, tooltip: 'খুঁজুন', tonal: true, onPressed: () {}),
        ],
      ),
    );
    final c = colorsOf(tester);
    expect(tester.getSize(find.byTooltip('সেটিংস')), const Size.square(DLSize.touch));
    expect(tester.getSize(find.byTooltip('খুঁজুন')), const Size.square(DLSize.controlMd));
    expect(groundOf(tester, find.byTooltip('খুঁজুন')).color, c.accentSoft);
    expect(tester.widget<Icon>(find.byIcon(DLIcons.search)).color, c.accentText);
    expect(tester.widget<Icon>(find.byIcon(DLIcons.gear)).color, c.textPrimary);
    await tester.tap(find.byTooltip('সেটিংস'));
    await tester.pump();
    expect(taps, 1);

    // The icon-only button's accessible label is its tooltip.
    final semantics = tester.ensureSemantics();
    expect(tester.getSemantics(find.descendant(of: find.byType(DLIconButton).first, matching: find.byType(DLPressable))), containsSemantics(label: 'সেটিংস', isButton: true));
    semantics.dispose();
  });

  testWidgets('DLLinkButton and DLFab', (tester) async {
    var added = false;
    await pumpDL(
      tester,
      Column(
        children: [
          DLLinkButton(label: 'সব দেখুন', onPressed: () {}),
          DLFab(tooltip: bn.add, onPressed: () => added = true),
        ],
      ),
    );
    final c = colorsOf(tester);
    expect(styleOf(tester, 'সব দেখুন').color, c.accentText);
    expect(find.byIcon(DLIcons.chevronRight), findsOneWidget);
    expect(tester.getSize(find.byType(DLLinkButton)).height, greaterThanOrEqualTo(DLSize.controlMd));

    expect(tester.getSize(find.byType(DLFab)), const Size.square(DLSize.fab));
    final fab = groundOf(tester, find.byType(DLFab));
    expect(fab.color, c.accent);
    expect(fab.boxShadow, DLShadows.fab(Brightness.light));
    expect(tester.widget<Icon>(find.byIcon(DLIcons.plus)).color, c.onAccent);
    await tester.tap(find.byTooltip(bn.add));
    await tester.pump();
    expect(added, isTrue);
  });

  testWidgets('DLAppBar: root and sub-page variants, back pops, close uses its own label', (tester) async {
    await pumpDL(
      tester,
      Builder(
        builder: (context) => DLButton(
          label: 'খুলুন',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(appBar: DLAppBar(title: 'লেনদেনের বিবরণ')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('খুলুন'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(DLAppBar)).height, DLAppBar.height);
    expect(styleOf(tester, 'লেনদেনের বিবরণ').fontSize, DLText.textH2.fontSize);
    await tester.tap(find.byTooltip(bn.back));
    await tester.pumpAndSettle();
    expect(find.text('লেনদেনের বিবরণ'), findsNothing);

    var closed = false;
    await pumpDL(
      tester,
      Column(
        children: [
          const DLAppBar.root(title: 'হিসাব'),
          DLAppBar(title: 'খরচ যোগ করুন', leading: DLAppBarLeading.close, onLeading: () => closed = true),
        ],
      ),
    );
    expect(styleOf(tester, 'হিসাব').fontSize, DLText.textH1.fontSize);
    expect(find.byTooltip(bn.back), findsNothing);
    await tester.tap(find.byTooltip(bn.close));
    await tester.pump();
    expect(closed, isTrue);
  });
}
