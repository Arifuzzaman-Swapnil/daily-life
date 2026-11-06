import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../prefs/app_settings.dart';
import '../prefs/privacy_prefs.dart';
import 'dl_format.dart';

/// The formatter for every number and date a person reads. Rebuilt whenever
/// language, digit style, date style or "Hide amounts" changes. Exports use
/// `f.unmasked` (dl_format_more.dart) so they keep the real amounts.
final formatProvider = Provider<DLFormat>((ref) {
  final s = ref.watch(settingsProvider);
  final hide = ref.watch(privacyProvider.select((p) => p.hideAmounts));
  return DLFormat(lang: s.lang, digits: s.digits, dateStyle: s.dateStyle, hideAmounts: hide);
});

/// The device clock, injectable so tests can pin "today" (the prototype uses 2026-11-06).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
