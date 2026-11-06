import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../prefs/app_settings.dart';
import 'dl_format.dart';

/// The formatter for every number and date a person reads. Rebuilt whenever
/// language, digit style or date style changes.
final formatProvider = Provider<DLFormat>((ref) {
  final s = ref.watch(settingsProvider);
  return DLFormat(lang: s.lang, digits: s.digits, dateStyle: s.dateStyle);
});

/// The device clock, injectable so tests can pin "today" (the prototype uses 2026-11-06).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
