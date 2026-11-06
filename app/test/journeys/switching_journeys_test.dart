// Acceptance journeys 10–12: language and theme switches with the sample data
// loaded, so the sample records are relocalized too. Each walks every screen
// (see tour.dart). Journeys 1–9 live with their areas:
//   1 onboarding/onboarding_test.dart       2–5 finance/finance_journeys_test.dart
//   6 work/work_journey_test.dart           7 calendar/calendar_screens_test.dart
//   8 reminders/reminders_test.dart         9 notes/notes_test.dart
import 'package:dailylife/core/format/dl_format.dart';
import 'package:dailylife/core/prefs/app_settings.dart';
import 'package:dailylife/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'tour.dart';

const _n1Bn = 'ডিসেম্বরের বাজেট পরিকল্পনা';
const _n1En = 'December budget plan';

/// Sample data that follows the language, as on a CI build.
const _samplePrefs = {PrefKeys.sampleData: true};

void main() {
  testWidgets('journey 10: Settings → English, every screen has no Bengali left, then back to Bengali', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTourPhone, prefs: _samplePrefs);
    final before = await dumpDatabase(db);

    await tapInSettings(tester, 'English');
    expect(find.text('Settings'), findsOneWidget);
    await waitForSampleTitle(tester, db, _n1En);
    expect(containerOf(tester).read(settingsProvider).digits, DigitStyle.en);

    final bengaliLeft = <String, List<String>>{};
    await tour(tester, fullTour, (stop) {
      final texts = screenTexts(tester, skip: skipLanguageCards);
      expect(texts, isNotEmpty, reason: stop);
      final bn = texts.where(bengali.hasMatch).toSet().toList();
      if (bn.isNotEmpty) bengaliLeft[stop] = bn;
    });
    expect(bengaliLeft, isEmpty, reason: 'Bengali text on English screens');

    // Back to Bengali: labels, digits and the sample text return.
    await tapInSettings(tester, 'বাংলা');
    expect(find.text('সেটিংস'), findsOneWidget);
    await waitForSampleTitle(tester, db, _n1Bn);
    expect(containerOf(tester).read(settingsProvider).digits, DigitStyle.bn);
    await show(tester, Routes.home);
    for (final label in ['হোম', 'হিসাব', 'ক্যালেন্ডার', 'কাজ', 'আরও']) {
      expect(navLabel(label), findsOneWidget, reason: label);
    }
    await show(tester, Routes.notes);
    expect(find.text(_n1Bn), findsOneWidget);
    expect(await dumpDatabase(db), before, reason: 'the round trip changes no record');
  });

  testWidgets('journey 11: Light → Dark → System; every screen, sheet, dialog, chart and input follows', (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpApp(tester, sampleData: true, size: kTourPhone, prefs: _samplePrefs);

    Future<void> walk(List<Stop> stops, Brightness expected) async {
      final wrong = expected == Brightness.light ? Brightness.dark : Brightness.light;
      final leaks = <String, List<String>>{};
      await tour(tester, stops, (stop) {
        expect(appBrightness(tester), expected, reason: stop);
        expect(themeOnlyColours(tester, expected), isNotEmpty, reason: stop);
        final bad = themeOnlyColours(tester, wrong);
        if (bad.isNotEmpty) leaks[stop] = bad;
      });
      expect(leaks, isEmpty, reason: '${wrong.name}-only colours in the ${expected.name} theme');
    }

    await walk(fullTour, Brightness.light);

    await tapInSettings(tester, 'ডার্ক');
    expect(containerOf(tester).read(settingsProvider).themeMode, ThemeMode.dark);
    await walk(fullTour, Brightness.dark);

    // System follows the phone: light here, then the phone turns dark.
    await tapInSettings(tester, 'সিস্টেম ডিফল্ট');
    expect(containerOf(tester).read(settingsProvider).themeMode, ThemeMode.system);
    await walk(shortTour, Brightness.light);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    await walk(shortTour, Brightness.dark);
  });

  testWidgets('journey 12: English + Dark together, then Bengali + Light: everything returns', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTourPhone, prefs: _samplePrefs);
    final textsBefore = <String, List<String>>{};
    await tour(tester, fullTour, (stop) => textsBefore[stop] = screenTexts(tester));
    final dataBefore = await dumpDatabase(db);

    await tapInSettings(tester, 'English');
    await tapInSettings(tester, 'Dark');
    await waitForSampleTitle(tester, db, _n1En);
    final enDark = <String, List<String>>{};
    await tour(tester, fullTour, (stop) {
      expect(appBrightness(tester), Brightness.dark, reason: stop);
      expect(themeOnlyColours(tester, Brightness.dark), isNotEmpty, reason: stop);
      final problems = [
        ...screenTexts(tester, skip: skipLanguageCards).where(bengali.hasMatch).toSet(),
        ...themeOnlyColours(tester, Brightness.light),
      ];
      if (problems.isNotEmpty) enDark[stop] = problems;
    });
    expect(enDark, isEmpty, reason: 'Bengali text or light colours in English + Dark');

    await tapInSettings(tester, 'বাংলা');
    await tapInSettings(tester, 'লাইট');
    await waitForSampleTitle(tester, db, _n1Bn);
    final changed = <String, List<String>>{};
    await tour(tester, fullTour, (stop) {
      expect(appBrightness(tester), Brightness.light, reason: stop);
      expect(themeOnlyColours(tester, Brightness.light), isNotEmpty, reason: stop);
      final texts = screenTexts(tester);
      final was = textsBefore[stop]!;
      final diff = [
        for (final s in texts.toSet().difference(was.toSet())) '+ $s',
        for (final s in was.toSet().difference(texts.toSet())) '- $s',
        ...themeOnlyColours(tester, Brightness.dark),
      ];
      if (diff.isNotEmpty) changed[stop] = diff;
    });
    expect(changed, isEmpty, reason: 'Bengali + Light differs from before the round trip');
    expect(await dumpDatabase(db), dataBefore, reason: 'the round trip changes no record');
    final s = containerOf(tester).read(settingsProvider);
    expect((s.lang, s.digits, s.themeMode), (AppLang.bn, DigitStyle.bn, ThemeMode.light));
  });
}
