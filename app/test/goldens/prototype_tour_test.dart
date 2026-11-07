// The step 8.3 prototype tour: renders every kit screen to a PNG, so I can
// lay them side by side with `daily-life-kit/screenshots/` (393-wide pages)
// and sanity-check them at 360 dp (the narrowest supported phone, where
// overflow and Bengali glyph clipping first show up).
//
// Tagged `tour`, skipped on a normal push. Dispatch the "Build APK" workflow
// with `tour=true` and the PNGs come back as the `prototype-tour` artifact.
// They are never committed.
import 'package:dailylife/core/prefs/app_settings.dart';
import 'package:dailylife/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'screens.dart';

const _variants = [
  // 393-wide: matches the kit screenshots at `daily-life-kit/screenshots/`.
  // Height is generous so the whole scrolling page builds in one capture.
  ('bangla-light-393', 393.0, 2400.0, <String, Object>{}),
  ('english-dark-393', 393.0, 2400.0, <String, Object>{PrefKeys.lang: 'en', PrefKeys.digits: 'en', PrefKeys.themeMode: 'dark'}),

  // 360-wide: the narrowest phone. Catches overflow and Bengali clipping
  // that the 393-wide goldens don't show. Height is a phone's, not full
  // page, so chrome at the fold is also captured.
  ('bangla-light-360', 360.0, 852.0, <String, Object>{}),
  ('english-dark-360', 360.0, 852.0, <String, Object>{PrefKeys.lang: 'en', PrefKeys.digits: 'en', PrefKeys.themeMode: 'dark'}),
];

void main() {
  for (final (variant, width, height, variantPrefs) in _variants) {
    for (final s in prototypeScreens) {
      testWidgets('tour: ${s.slug} ($variant)', (tester) async {
        await pumpApp(
          tester,
          sampleData: true,
          size: Size(width, height),
          prefs: {...variantPrefs, ...s.extraPrefs, PrefKeys.displayName: 'Swapnil', PrefKeys.sampleData: true},
          onboarded: s.onboarded,
        );
        final t = lookupAppLocalizations(Locale(containerOf(tester).read(settingsProvider).lang.name));
        await s.open(tester, t);

        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        // The workflow runs with `--update-goldens`, so these are always
        // (re)written and uploaded as the `prototype-tour` artifact. The
        // path lands at `test/goldens/_tour/<variant>/<slug>.png`.
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/_tour/$variant/${s.slug}.png'),
        );
      }, tags: ['tour']);
    }
  }
}
