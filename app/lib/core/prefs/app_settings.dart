// App-wide preferences (language, digits, date style, Bangla calendar line, theme),
// persisted in shared_preferences. Every screen reads these through Riverpod, so a
// change rebuilds the whole app instantly without touching navigation state.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../format/dl_format.dart';

/// The SharedPreferences instance, loaded once in `main()` and injected with an override.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider must be overridden in main()'),
);

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

@immutable
class AppSettings {
  const AppSettings({
    this.lang = AppLang.bn,
    this.digits = DigitStyle.bn,
    this.dateStyle = DateStyle.written,
    this.banglaDate = true,
    this.themeMode = ThemeMode.light,
    this.displayName = '',
  });

  /// First launch: Bengali, Bengali digits, written dates, Bangla calendar line on, Light theme.
  static const defaults = AppSettings();

  final AppLang lang;
  final DigitStyle digits;
  final DateStyle dateStyle;
  final bool banglaDate;
  final ThemeMode themeMode;

  /// The name Home greets (set by onboarding, step 7). Empty until then.
  final String displayName;

  Locale get locale => Locale(lang.name);

  AppSettings copyWith({AppLang? lang, DigitStyle? digits, DateStyle? dateStyle, bool? banglaDate, ThemeMode? themeMode, String? displayName}) =>
      AppSettings(
        lang: lang ?? this.lang,
        digits: digits ?? this.digits,
        dateStyle: dateStyle ?? this.dateStyle,
        banglaDate: banglaDate ?? this.banglaDate,
        themeMode: themeMode ?? this.themeMode,
        displayName: displayName ?? this.displayName,
      );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.lang == lang &&
      other.digits == digits &&
      other.dateStyle == dateStyle &&
      other.banglaDate == banglaDate &&
      other.themeMode == themeMode &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(lang, digits, dateStyle, banglaDate, themeMode, displayName);
}

/// Storage keys. Values are enum `.name`s so they stay readable in backups.
abstract final class PrefKeys {
  static const lang = 'pref.lang';
  static const digits = 'pref.digits';
  static const dateStyle = 'pref.dateStyle';
  static const banglaDate = 'pref.banglaDate';
  static const themeMode = 'pref.themeMode';
  static const displayName = 'pref.displayName';

  /// Home dashboard: section names in order, and the hidden ones.
  static const dashOrder = 'pref.dash.order';
  static const dashHidden = 'pref.dash.hidden';

  /// Daily water target in ml.
  static const waterTarget = 'pref.waterTarget';

  /// Sample data: true once seeded, false when the person turned it off, absent
  /// when never decided.
  static const sampleData = 'pref.sampleData';
}

class SettingsController extends Notifier<AppSettings> {
  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);

  @override
  AppSettings build() {
    final p = ref.watch(sharedPrefsProvider);
    const d = AppSettings.defaults;
    return AppSettings(
      lang: _enum(AppLang.values, p.getString(PrefKeys.lang)) ?? d.lang,
      digits: _enum(DigitStyle.values, p.getString(PrefKeys.digits)) ?? d.digits,
      dateStyle: _enum(DateStyle.values, p.getString(PrefKeys.dateStyle)) ?? d.dateStyle,
      banglaDate: p.getBool(PrefKeys.banglaDate) ?? d.banglaDate,
      themeMode: _enum(ThemeMode.values, p.getString(PrefKeys.themeMode)) ?? d.themeMode,
      displayName: p.getString(PrefKeys.displayName) ?? d.displayName,
    );
  }

  /// Changing the language also switches digits to match (bn → Bengali digits,
  /// en → English digits). The user can override digits afterwards.
  Future<void> setLanguage(AppLang lang) async {
    final digits = lang == AppLang.bn ? DigitStyle.bn : DigitStyle.en;
    state = state.copyWith(lang: lang, digits: digits);
    await _prefs.setString(PrefKeys.lang, lang.name);
    await _prefs.setString(PrefKeys.digits, digits.name);
  }

  Future<void> setDigits(DigitStyle digits) async {
    state = state.copyWith(digits: digits);
    await _prefs.setString(PrefKeys.digits, digits.name);
  }

  Future<void> setDateStyle(DateStyle style) async {
    state = state.copyWith(dateStyle: style);
    await _prefs.setString(PrefKeys.dateStyle, style.name);
  }

  Future<void> setBanglaDate(bool on) async {
    state = state.copyWith(banglaDate: on);
    await _prefs.setBool(PrefKeys.banglaDate, on);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(PrefKeys.themeMode, mode.name);
  }

  Future<void> setDisplayName(String name) async {
    final trimmed = name.trim();
    state = state.copyWith(displayName: trimmed);
    await _prefs.setString(PrefKeys.displayName, trimmed);
  }

  static T? _enum<T extends Enum>(List<T> values, String? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}
