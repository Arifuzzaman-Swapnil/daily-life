import 'package:dailylife/core/format/dl_format.dart';
import 'package:dailylife/core/format/format_provider.dart';
import 'package:dailylife/core/prefs/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> makeContainer([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('first launch defaults: Bengali, Bengali digits, written dates, Bangla date on, Light', () async {
    final c = await makeContainer();
    expect(c.read(settingsProvider), AppSettings.defaults);
    final s = c.read(settingsProvider);
    expect(s.lang, AppLang.bn);
    expect(s.digits, DigitStyle.bn);
    expect(s.dateStyle, DateStyle.written);
    expect(s.banglaDate, isTrue);
    expect(s.themeMode, ThemeMode.light);
    expect(s.locale, const Locale('bn'));
  });

  test('changing language also switches digits to match', () async {
    final c = await makeContainer();
    final ctl = c.read(settingsProvider.notifier);

    await ctl.setLanguage(AppLang.en);
    expect(c.read(settingsProvider).lang, AppLang.en);
    expect(c.read(settingsProvider).digits, DigitStyle.en);

    await ctl.setLanguage(AppLang.bn);
    expect(c.read(settingsProvider).digits, DigitStyle.bn);
  });

  test('digits can be overridden after choosing a language', () async {
    final c = await makeContainer();
    final ctl = c.read(settingsProvider.notifier);
    await ctl.setLanguage(AppLang.en);
    await ctl.setDigits(DigitStyle.bn);
    expect(c.read(settingsProvider).lang, AppLang.en);
    expect(c.read(settingsProvider).digits, DigitStyle.bn);
    expect(c.read(formatProvider).taka(125000), '৳১,২৫,০০০');
  });

  test('formatter follows settings instantly', () async {
    final c = await makeContainer();
    final today = DateTime(2026, 11, 6);
    expect(c.read(formatProvider).dateLong(today), '৬ নভেম্বর, শুক্রবার');
    await c.read(settingsProvider.notifier).setLanguage(AppLang.en);
    expect(c.read(formatProvider).dateLong(today), 'Friday, 6 November');
    await c.read(settingsProvider.notifier).setDateStyle(DateStyle.numeric);
    expect(c.read(formatProvider).dateMedium(today), '06/11/2026');
  });

  test('every setting persists across restarts', () async {
    final c = await makeContainer();
    final ctl = c.read(settingsProvider.notifier);
    await ctl.setLanguage(AppLang.en);
    await ctl.setDigits(DigitStyle.bn);
    await ctl.setDateStyle(DateStyle.numeric);
    await ctl.setBanglaDate(false);
    await ctl.setThemeMode(ThemeMode.system);

    // A fresh container reading the same SharedPreferences = an app restart.
    final prefs = await SharedPreferences.getInstance();
    final restarted = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
    addTearDown(restarted.dispose);
    expect(
      restarted.read(settingsProvider),
      const AppSettings(lang: AppLang.en, digits: DigitStyle.bn, dateStyle: DateStyle.numeric, banglaDate: false, themeMode: ThemeMode.system),
    );
  });

  test('unknown stored values fall back to defaults', () async {
    final c = await makeContainer({PrefKeys.lang: 'fr', PrefKeys.themeMode: 'sepia'});
    expect(c.read(settingsProvider).lang, AppLang.bn);
    expect(c.read(settingsProvider).themeMode, ThemeMode.light);
  });
}
