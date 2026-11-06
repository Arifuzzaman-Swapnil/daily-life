// Documents and reports (step 6.6) on a 360dp phone, in English + Dark and
// Bengali + Light, with and without data. Any overflow fails the test.
import 'package:dailylife/core/prefs/app_settings.dart';
import 'package:dailylife/features/reports/reports_providers.dart';
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
    testWidgets('Documents and reports lay out on a 360dp phone ($name)', (tester) async {
      await pumpApp(tester, prefs: prefs, sampleData: sample, size: const Size(360, 3000));
      for (final route in [
        Routes.documents,
        Routes.importDoc,
        if (sample) ...[Routes.document('d1'), Routes.document('d5')],
        for (final tab in ReportTab.values) Routes.reportsTab(tab),
      ]) {
        await openRoute(tester, route);
        expect(tester.takeException(), isNull, reason: route);
      }
      // A year of bars.
      await openRoute(tester, Routes.reports);
      await tapOn(tester, find.text(prefs[PrefKeys.lang] == 'en' ? 'Year' : 'বছর'));
      expect(tester.takeException(), isNull);
    });
  }
}
