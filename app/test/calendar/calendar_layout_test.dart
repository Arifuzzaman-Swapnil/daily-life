// Every Calendar screen (step 6.2) on a 360dp phone, in English + Dark and
// Bengali + Light, with and without data. Any overflow fails the test.
import 'package:dailylife/core/prefs/app_settings.dart';
import 'package:dailylife/features/calendar/calendar_providers.dart';
import 'package:dailylife/features/calendar/calendar_screen.dart';
import 'package:dailylife/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  for (final (name, prefs, sample) in [
    ('English + Dark', {PrefKeys.lang: 'en', PrefKeys.digits: 'en', PrefKeys.themeMode: 'dark'}, true),
    ('Bengali + Light', <String, Object>{}, true),
    ('Bengali + Light, no data', <String, Object>{}, false),
  ]) {
    testWidgets('Calendar screens lay out on a 360dp phone ($name)', (tester) async {
      await pumpApp(tester, prefs: prefs, sampleData: sample, size: const Size(360, 2400));
      final en = prefs[PrefKeys.lang] == 'en';
      await tester.tap(navLabel(en ? 'Calendar' : 'ক্যালেন্ডার'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(Theme.of(tester.element(find.byType(CalendarScreen))).brightness, en ? Brightness.dark : Brightness.light);

      final ctl = containerOf(tester).read(calendarProvider.notifier);
      for (final view in CalView.values) {
        ctl.setView(view);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: view.name);
      }
      // A month that needs 6 rows: January 2027 starts on a Friday.
      ctl.setView(CalView.month);
      ctl.select(DateTime(2027, 1, 31));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (final route in [
        Routes.newEvent,
        if (sample) ...[Routes.event('ev1'), Routes.event('ev3'), Routes.editEvent('ev4')],
      ]) {
        await openRoute(tester, route);
        expect(tester.takeException(), isNull, reason: route);
      }
    });
  }
}
