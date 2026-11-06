// Health and goals (step 6.5) on a 360dp phone, in English + Dark and
// Bengali + Light, with and without data. Any overflow fails the test.
import 'package:dailylife/core/db/app_database.dart';
import 'package:dailylife/core/prefs/app_settings.dart';
import 'package:dailylife/features/health/health_providers.dart';
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
    testWidgets('Health and goals lay out on a 360dp phone ($name)', (tester) async {
      await pumpApp(tester, prefs: prefs, sampleData: sample, size: const Size(360, 2400));
      for (final route in [
        for (final tab in HealthTab.values) Routes.healthTab(tab),
        Routes.newMeal(MealType.dinner),
        Routes.goals,
        Routes.newGoal,
        if (sample) ...[Routes.editMeal('m1'), Routes.habit('h1'), Routes.habit('h5'), Routes.goal('gl1'), Routes.goal('gl5'), Routes.editGoal('gl2')],
      ]) {
        await openRoute(tester, route);
        expect(tester.takeException(), isNull, reason: route);
      }
    });
  }
}
