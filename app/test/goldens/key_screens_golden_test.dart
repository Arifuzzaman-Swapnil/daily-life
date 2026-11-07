// Goldens for the key screens in both languages × both themes at 393×852.
// Baselines live in `test/goldens/_baselines/` next to this file. They are
// generated and updated on CI only (see .github/workflows/build-apk.yml):
// run the "Build APK" workflow with "goldens=update" → the PNGs are uploaded
// as the "goldens" artifact; "goldens=check" compares against the baselines
// and uploads failure diffs.
//
// These are not full-page captures of every scrolling screen (step 8.3's
// prototype tour does that against daily-life-kit/screenshots/). They are a
// phone-sized snapshot of the chrome of each key screen in both themes and
// both languages, so a regression on a surface, a text colour or an icon
// jumps out at CI without a visual pass.
import 'package:dailylife/core/prefs/app_settings.dart';
import 'package:dailylife/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'screens.dart';

const _variants = [
  ('bn-light', <String, Object>{}),
  ('bn-dark', <String, Object>{PrefKeys.themeMode: 'dark'}),
  ('en-light', <String, Object>{PrefKeys.lang: 'en', PrefKeys.digits: 'en'}),
  ('en-dark', <String, Object>{PrefKeys.lang: 'en', PrefKeys.digits: 'en', PrefKeys.themeMode: 'dark'}),
];

void main() {
  for (final (variant, variantPrefs) in _variants) {
    for (final s in keyScreens) {
      testWidgets('golden: ${s.slug} ($variant)', (tester) async {
        await pumpApp(
          tester,
          sampleData: true,
          size: const Size(393, 852),
          prefs: {...variantPrefs, ...s.extraPrefs, PrefKeys.displayName: 'Swapnil', PrefKeys.sampleData: true},
          onboarded: s.onboarded,
        );
        final t = lookupAppLocalizations(Locale(containerOf(tester).read(settingsProvider).lang.name));
        await s.open(tester, t);

        // Let any animation finish so the capture is stable.
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        // Flutter resolves this path against `test/`, not the test's own
        // folder — hence the `goldens/` prefix so baselines land next to this
        // file at `test/goldens/_baselines/`.
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/_baselines/${s.slug}-$variant.png'),
        );
      }, tags: ['golden']);
    }
  }
}
