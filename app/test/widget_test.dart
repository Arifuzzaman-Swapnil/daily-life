import 'package:dailylife/core/theme/dl_tokens.dart';
import 'package:dailylife/core/widgets/dl_bottom_nav.dart';
import 'package:dailylife/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('first launch: Bengali + Light, Home tab, navy nav with 5 tabs', (tester) async {
    await pumpApp(tester);

    for (final label in ['হোম', 'হিসাব', 'ক্যালেন্ডার', 'কাজ', 'আরও']) {
      expect(navLabel(label), findsOneWidget, reason: label);
    }
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('আজকের দিনটি সুন্দর হোক।'), findsOneWidget);

    // Formatted values follow the Bengali defaults.
    expect(find.text('৬ নভেম্বর, শুক্রবার'), findsOneWidget);
    expect(find.text('২১ কার্তিক ১৪৩৩'), findsOneWidget);
    expect(find.text('+৳০ এ মাসে'), findsOneWidget);

    final ctx = tester.element(find.byType(DLBottomNav));
    expect(Theme.of(ctx).brightness, Brightness.light);
    expect(ctx.dl.brand, DLColors.light.brand);
  });

  testWidgets('bottom nav switches tabs and the More tab opens Settings without the nav', (tester) async {
    await pumpApp(tester);

    await tester.tap(navLabel('হিসাব'));
    await tester.pumpAndSettle();
    expect(titleBar('হিসাব'), findsOneWidget);

    await tester.tap(navLabel('আরও'));
    await tester.pumpAndSettle();
    expect(titleBar('আরও'), findsOneWidget);

    await tapOn(tester, find.text('সেটিংস').last);
    expect(find.text('ভাষা ও অঞ্চল'), findsOneWidget);
    expect(find.byType(DLBottomNav), findsNothing);

    await tester.tap(find.byTooltip('পেছনে যান'));
    await tester.pumpAndSettle();
    expect(titleBar('আরও'), findsOneWidget);
    expect(find.byType(DLBottomNav), findsOneWidget);
  });
}
