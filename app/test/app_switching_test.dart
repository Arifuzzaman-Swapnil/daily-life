// Build step 1 acceptance: language, digits and theme switch instantly,
// app-wide, without losing navigation state.
import 'package:dailylife/core/format/dl_format.dart';
import 'package:dailylife/core/prefs/app_settings.dart';
import 'package:dailylife/core/theme/dl_tokens.dart';
import 'package:dailylife/features/settings/settings_screen.dart';
import 'package:dailylife/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Finder inSettings(Finder f) => find.descendant(of: find.byType(SettingsScreen), matching: f);

Future<void> scrollSettingsTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 200, scrollable: inSettings(find.byType(Scrollable)).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('switching to English rebuilds every label instantly and keeps the current tab', (tester) async {
    await pumpApp(tester);

    // Go to the Work tab, then open Settings on top of it.
    await tester.tap(navLabel('কাজ'));
    await tester.pumpAndSettle();
    expect(titleBar('কাজ'), findsOneWidget);
    containerOf(tester).read(routerProvider).push(Routes.settings);
    await tester.pumpAndSettle();
    expect(find.text('সেটিংস'), findsOneWidget);

    await tester.tap(inSettings(find.text('English')));
    await tester.pump(); // one frame: the switch is instant

    // Still on Settings, now in English, with English digits.
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Language & region'), findsOneWidget);
    expect(find.text('৳125,000 · 65%'), findsOneWidget);
    expect(containerOf(tester).read(settingsProvider).digits, DigitStyle.en);
    await tester.pumpAndSettle();

    // Back to the shell: same tab (Work), all nav labels in English.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(titleBar('Work'), findsOneWidget);
    for (final label in ['Home', 'Finance', 'Calendar', 'Work', 'More']) {
      expect(navLabel(label), findsOneWidget, reason: label);
    }
    for (final label in ['হোম', 'হিসাব', 'ক্যালেন্ডার', 'কাজ', 'আরও']) {
      expect(find.text(label), findsNothing, reason: label);
    }
    expect(find.text('Friday, 6 November'), findsOneWidget);
    expect(find.text('21 Kartik 1433'), findsOneWidget);
  });

  testWidgets('digit style can be overridden independently of the language', (tester) async {
    await pumpApp(tester);
    containerOf(tester).read(routerProvider).push(Routes.settings);
    await tester.pumpAndSettle();

    await tester.tap(inSettings(find.text('English')));
    await tester.pumpAndSettle();
    await tester.tap(inSettings(find.text('Bengali digits')));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('৳১,২৫,০০০ · ৬৫%'), findsOneWidget);
  });

  testWidgets('theme switches Light → Dark → System and every surface follows', (tester) async {
    await pumpApp(tester);
    containerOf(tester).read(routerProvider).push(Routes.settings);
    await tester.pumpAndSettle();

    DLColors colors() => tester.element(find.byType(SettingsScreen)).dl;
    Brightness brightness() => Theme.of(tester.element(find.byType(SettingsScreen))).brightness;
    expect(brightness(), Brightness.light);
    expect(colors().background, DLColors.light.background);

    await scrollSettingsTo(tester, inSettings(find.text('ডার্ক')));
    await tester.tap(inSettings(find.text('ডার্ক')));
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.dark);
    expect(colors().background, DLColors.dark.background);
    expect(colors().surface, DLColors.dark.surface);
    expect(containerOf(tester).read(settingsProvider).themeMode, ThemeMode.dark);

    // System follows the phone (light in the test environment) and shows the note.
    await tester.tap(inSettings(find.text('সিস্টেম ডিফল্ট')));
    await tester.pumpAndSettle();
    expect(containerOf(tester).read(settingsProvider).themeMode, ThemeMode.system);
    expect(brightness(), Brightness.light);
    expect(find.text('ফোনের থিম অনুসরণ করে · লাইট'), findsOneWidget);

    // Phone switches to dark → the app follows without a restart.
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.dark);
    expect(find.text('ফোনের থিম অনুসরণ করে · ডার্ক'), findsOneWidget);
  });

  testWidgets('settings survive a restart', (tester) async {
    await pumpApp(tester, prefs: {PrefKeys.lang: 'en', PrefKeys.digits: 'en', PrefKeys.themeMode: 'dark'});
    expect(titleBar('Home'), findsOneWidget);
    expect(find.text('৳125,000'), findsOneWidget);
    expect(Theme.of(tester.element(find.byType(Scaffold).first)).brightness, Brightness.dark);
  });
}
