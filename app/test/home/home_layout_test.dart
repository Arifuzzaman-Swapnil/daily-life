// Home, its sheets and the notifications page on a 360dp phone, in English +
// Dark and Bengali + Light, with and without data. Any overflow fails the test.
import 'package:dailylife/core/prefs/app_settings.dart';
import 'package:dailylife/core/widgets/dl_widgets.dart';
import 'package:dailylife/features/home/home_screen.dart';
import 'package:dailylife/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  for (final (name, prefs, sample) in [
    ('English + Dark', {PrefKeys.lang: 'en', PrefKeys.digits: 'en', PrefKeys.themeMode: 'dark', PrefKeys.displayName: 'Swapnil'}, true),
    ('Bengali + Light', <String, Object>{PrefKeys.displayName: 'স্বপ্নিল'}, true),
    ('Bengali + Light, no data', <String, Object>{}, false),
  ]) {
    testWidgets('Home, its sheets and notifications lay out on a 360dp phone ($name)', (tester) async {
      // Tall enough to build the whole dashboard; the narrow width is the test.
      await pumpApp(tester, prefs: prefs, sampleData: sample, size: const Size(360, 2800));
      final en = prefs[PrefKeys.lang] == 'en';
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(Theme.of(tester.element(find.byType(HomeScreen))).brightness, en ? Brightness.dark : Brightness.light);

      Future<void> closeSheet() async {
        await tester.tapAt(const Offset(180, 20)); // the scrim closes the sheet
        await tester.pumpAndSettle();
        expect(find.byType(DLSheet), findsNothing);
      }

      await tapOn(tester, find.descendant(of: find.byType(DLBalanceHero), matching: find.byType(DLHeroPill)));
      expect(find.byType(DLSheet), findsOneWidget);
      await closeSheet();

      await tapOn(tester, find.text(en ? '12 months' : '১২ মাস'));
      expect(tester.widget<DLBarChart>(find.byType(DLBarChart)).groups.length, 12);

      await tapOn(tester, find.text(en ? 'Customize dashboard' : 'ড্যাশবোর্ড সাজান'));
      expect(find.byType(DLSheet), findsOneWidget);
      await closeSheet();

      await openRoute(tester, Routes.notifications);
      expect(titleBar(en ? 'Notifications' : 'নোটিফিকেশন'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
