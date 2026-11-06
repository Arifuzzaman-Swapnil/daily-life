// More, Reminders and the Notebook (step 6.3) on a 360dp phone, in English +
// Dark and Bengali + Light, with and without data. Any overflow fails the test.
import 'package:dailylife/core/prefs/app_settings.dart';
import 'package:dailylife/core/widgets/dl_widgets.dart';
import 'package:dailylife/features/more/more_screen.dart';
import 'package:dailylife/features/notes/notes_providers.dart';
import 'package:dailylife/features/reminders/reminders_providers.dart';
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
    testWidgets('More, Reminders and Notebook lay out on a 360dp phone ($name)', (tester) async {
      await pumpApp(tester, prefs: prefs, sampleData: sample, size: const Size(360, 2400));
      final en = prefs[PrefKeys.lang] == 'en';
      await tester.tap(navLabel(en ? 'More' : 'আরও'));
      await tester.pumpAndSettle();
      expect(find.byType(MoreScreen), findsOneWidget);
      expect(Theme.of(tester.element(find.byType(MoreScreen))).brightness, en ? Brightness.dark : Brightness.light);

      await openRoute(tester, Routes.reminders);
      final remTab = containerOf(tester).read(remTabProvider.notifier);
      for (final tab in RemTab.values) {
        remTab.set(tab);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab.name);
      }

      // The form with custom days showing.
      await openRoute(tester, Routes.newReminder());
      await tapOn(tester, find.widgetWithText(DLChip, en ? 'Custom' : 'নিজস্ব'));
      expect(tester.takeException(), isNull);

      for (final route in [
        if (sample) ...[Routes.reminder('r1'), Routes.editReminder('r4'), Routes.note('n1'), Routes.editNote('n1')],
        Routes.notes,
        Routes.newNote,
      ]) {
        await openRoute(tester, route);
        expect(tester.takeException(), isNull, reason: route);
      }

      containerOf(tester).read(noteFilterProvider.notifier).toggleArchive();
      await openRoute(tester, Routes.notes);
      expect(tester.takeException(), isNull);
    });
  }
}
