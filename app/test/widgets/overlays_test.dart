import 'package:dailylife/core/theme/dl_tokens.dart';
import 'package:dailylife/core/widgets/dl_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/// A button that runs [action] with a context under the app's navigator.
Widget opener(void Function(BuildContext context) action) =>
    Builder(builder: (context) => DLButton(label: 'খুলুন', onPressed: () => action(context)));

void main() {
  testWidgets('showDLSheet: handle, title, raised surface; closes on a scrim tap', (tester) async {
    await pumpDL(
      tester,
      opener((context) => showDLSheet<void>(context, title: 'মাস বেছে নিন', builder: (_) => const Text('নভেম্বর ২০২৬'))),
    );
    final c = colorsOf(tester);
    await tester.tap(find.text('খুলুন'));
    await tester.pumpAndSettle();
    expect(find.text('মাস বেছে নিন'), findsOneWidget);
    expect(find.text('নভেম্বর ২০২৬'), findsOneWidget);
    expect(styleOf(tester, 'মাস বেছে নিন').fontSize, DLText.textH2.fontSize);

    final sheet = tester.widget<Container>(find.descendant(of: find.byType(DLSheet), matching: find.byType(Container)).first);
    final deco = sheet.decoration! as BoxDecoration;
    expect(deco.color, c.surfaceRaised);
    expect(deco.borderRadius, const BorderRadius.vertical(top: Radius.circular(DLRadius.xl)));
    expect(deco.boxShadow, DLShadows.sheet(Brightness.light));
    final handle = find.byWidgetPredicate((w) => w is Container && w.constraints?.maxWidth == 40 && w.constraints?.maxHeight == 4);
    expect(handle, findsOneWidget);

    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();
    expect(find.text('মাস বেছে নিন'), findsNothing);
  });

  testWidgets('showDLSheet never grows past 86 % of the screen; long content scrolls', (tester) async {
    await pumpDL(
      tester,
      opener((context) => showDLSheet<void>(context, title: 'ফিল্টার', builder: (_) => const SizedBox(height: 2000))),
    );
    await tester.tap(find.text('খুলুন'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(DLSheet)).height, lessThanOrEqualTo(852 * 0.86 + 0.5));
    expect(find.descendant(of: find.byType(DLSheet), matching: find.byType(SingleChildScrollView)), findsOneWidget);
  });

  testWidgets('showDLSheet returns the value the sheet pops with', (tester) async {
    String? result;
    await pumpDL(
      tester,
      opener((context) async {
        result = await showDLSheet<String>(
          context,
          title: 'যোগ করুন',
          builder: (context) => DLButton(label: 'আয়', onPressed: () => Navigator.pop(context, 'income')),
        );
      }),
    );
    await tester.tap(find.text('খুলুন'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('আয়'));
    await tester.pumpAndSettle();
    expect(result, 'income');
  });

  testWidgets('showDLConfirm: destructive by default, true only on confirm', (tester) async {
    final answers = <bool>[];
    await pumpDL(
      tester,
      opener((context) async => answers.add(await showDLConfirm(context, title: 'লেনদেনটি মুছে ফেলবেন?', body: '৳৪,২০০ · মাসিক বাজার'))),
    );
    final c = colorsOf(tester);

    await tester.tap(find.text('খুলুন'));
    await tester.pumpAndSettle();
    expect(find.text('লেনদেনটি মুছে ফেলবেন?'), findsOneWidget);
    expect(find.byIcon(DLIcons.trash), findsOneWidget);
    expect(groundOf(tester, find.widgetWithText(DLButton, bn.del)).color, c.danger);
    expect(groundOf(tester, find.widgetWithText(DLButton, bn.cancel)).color, c.surface);
    // 24 from the sides, its top at 30 % of the screen.
    final card = find.ancestor(of: find.byType(DLIconChip), matching: find.byType(Container)).first;
    expect(tester.getTopLeft(card).dx, 24);
    expect(tester.getTopLeft(card).dy, closeTo(852 * 0.3, 1));
    final cardDeco = tester.widget<Container>(card).decoration! as BoxDecoration;
    expect(cardDeco.color, c.surfaceRaised);
    expect(cardDeco.boxShadow, DLShadows.dialog(Brightness.light));
    await tester.tap(find.text(bn.del));
    await tester.pumpAndSettle();
    expect(answers, [true]);

    await tester.tap(find.text('খুলুন'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(bn.cancel));
    await tester.pumpAndSettle();
    expect(answers, [true, false]);

    await tester.tap(find.text('খুলুন'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(200, 60));
    await tester.pumpAndSettle();
    expect(answers, [true, false, false]);
  });

  testWidgets('showDLConfirm safe variant uses the info chip and the primary button', (tester) async {
    await pumpDL(
      tester,
      opener((context) => showDLConfirm(context, title: 'সম্পূর্ণ পরিশোধ করবেন?', confirmLabel: bn.confirm, safe: true)),
    );
    final c = colorsOf(tester);
    await tester.tap(find.text('খুলুন'));
    await tester.pumpAndSettle();
    expect(find.byIcon(DLIcons.info), findsOneWidget);
    expect(groundOf(tester, find.widgetWithText(DLButton, bn.confirm)).color, c.actionPrimary);
  });

  testWidgets('DLToast: shows above the nav area, lasts 2.4 s, a new toast replaces the old', (tester) async {
    await pumpDL(
      tester,
      Column(
        children: [
          Builder(builder: (context) => DLButton(label: 'এক', onPressed: () => DLToast.show(context, 'আয় সংরক্ষিত হয়েছে'))),
          Builder(builder: (context) => DLButton(label: 'দুই', onPressed: () => DLToast.show(context, 'ঘরগুলো ঠিক করুন', error: true))),
        ],
      ),
    );
    final c = colorsOf(tester);
    await tester.tap(find.text('এক'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('আয় সংরক্ষিত হয়েছে'), findsOneWidget);
    expect(tester.widget<Icon>(find.byIcon(DLIcons.checkCircle)).color, c.success);
    final box = find.ancestor(of: find.text('আয় সংরক্ষিত হয়েছে'), matching: find.byType(Container)).first;
    expect((tester.widget<Container>(box).decoration! as BoxDecoration).color, c.textPrimary);
    expect(tester.getBottomLeft(box), const Offset(16, 852 - 96));

    await tester.tap(find.text('দুই'));
    await tester.pump();
    expect(find.text('আয় সংরক্ষিত হয়েছে'), findsNothing);
    expect(find.text('ঘরগুলো ঠিক করুন'), findsOneWidget);
    expect(find.byIcon(DLIcons.alert), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2300));
    expect(find.text('ঘরগুলো ঠিক করুন'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(find.text('ঘরগুলো ঠিক করুন'), findsNothing);
  });
}
