// Every Work screen (step 6.1) on a 360dp phone, in English + Dark and
// Bengali + Light, with and without data. Any overflow fails the test.
import 'package:dailylife/core/prefs/app_settings.dart';
import 'package:dailylife/core/widgets/dl_widgets.dart';
import 'package:dailylife/features/work/work_screen.dart';
import 'package:dailylife/features/work/work_timer.dart';
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
    testWidgets('Work screens lay out on a 360dp phone ($name)', (tester) async {
      final clock = TestClock();
      // Tall enough to build whole lists; the narrow width is the test.
      await pumpApp(tester, prefs: prefs, sampleData: sample, size: const Size(360, 2400), clock: clock.call);
      final en = prefs[PrefKeys.lang] == 'en';

      await tester.tap(navLabel(en ? 'Work' : 'কাজ'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkScreen), findsOneWidget);
      expect(Theme.of(tester.element(find.byType(WorkScreen))).brightness, en ? Brightness.dark : Brightness.light);

      for (final route in [
        Routes.newTask(),
        if (sample) ...[Routes.task('k2'), Routes.editTask('k2'), Routes.project('p1')],
        Routes.workHistory,
        Routes.projects,
        Routes.timer,
      ]) {
        await openRoute(tester, route);
        expect(tester.takeException(), isNull, reason: route);
      }

      // The timer running, paused and stopped (the saved banner).
      final timer = containerOf(tester).read(workTimerProvider);
      await timer.start();
      await tester.pumpAndSettle();
      clock.advance(const Duration(hours: 1, minutes: 5, seconds: 7));
      await timer.pause();
      await tester.pumpAndSettle();
      await timer.stop();
      await tester.pumpAndSettle();
      expect(find.text(en ? 'Saved' : 'সংরক্ষিত'), findsOneWidget);

      // Validation errors on the task form.
      await openRoute(tester, Routes.newTask());
      await tapOn(tester, find.text(en ? 'Save' : 'সংরক্ষণ করুন'));
      expect(find.byType(DLErrorText), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
