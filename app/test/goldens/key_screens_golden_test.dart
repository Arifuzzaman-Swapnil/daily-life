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
import 'package:dailylife/core/db/app_database.dart';
import 'package:dailylife/core/prefs/app_settings.dart';
import 'package:dailylife/features/calendar/calendar_providers.dart';
import 'package:dailylife/features/health/health_providers.dart';
import 'package:dailylife/features/reports/reports_providers.dart';
import 'package:dailylife/l10n/app_localizations.dart';
import 'package:dailylife/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// A key screen: short [slug] (filename), the [prefs] passed to pumpApp, and
/// [open] drives the router there and leaves the screen settled.
typedef Screen = ({
  String slug,
  Map<String, Object> extraPrefs,
  bool onboarded,
  Future<void> Function(WidgetTester tester, AppLocalizations t) open,
});

Screen _screen(String slug, Future<void> Function(WidgetTester tester, AppLocalizations t) open,
        {Map<String, Object> extraPrefs = const {}, bool onboarded = true}) =>
    (slug: slug, extraPrefs: extraPrefs, onboarded: onboarded, open: open);

Future<void> _push(WidgetTester tester, String location) async {
  containerOf(tester).read(routerProvider).push(location);
  await tester.pumpAndSettle();
}

Future<void> _go(WidgetTester tester, String location) async {
  containerOf(tester).read(routerProvider).go(location);
  await tester.pumpAndSettle();
}

final List<Screen> screens = [
  _screen('01-welcome', (tester, t) async {}, onboarded: false),
  _screen('05-home', (tester, t) => _go(tester, Routes.home)),
  _screen('10-finance', (tester, t) => _go(tester, Routes.finance)),
  _screen('14-delete-dialog', (tester, t) async {
    await _push(tester, Routes.tx('t6'));
    await tester.tap(find.byTooltip(t.del));
    await tester.pumpAndSettle();
  }),
  _screen('16-add-expense', (tester, t) => _push(tester, Routes.newTx(TxType.expense))),
  _screen('20-allocation', (tester, t) => _push(tester, Routes.allocation)),
  _screen('25-shop-detail', (tester, t) => _push(tester, Routes.shop('s1'))),
  _screen('30-work', (tester, t) => _go(tester, Routes.work)),
  _screen('40-calendar-month', (tester, t) async {
    await _go(tester, Routes.calendar);
    containerOf(tester).read(calendarProvider.notifier).setView(CalView.month);
    await tester.pumpAndSettle();
  }),
  _screen('51-reminders', (tester, t) => _push(tester, Routes.reminders)),
  _screen('58-health-water', (tester, t) => _push(tester, Routes.healthTab(HealthTab.water))),
  _screen('70-reports-financial', (tester, t) => _push(tester, Routes.reportsTab(ReportTab.fin))),
  _screen('80-settings', (tester, t) => _push(tester, Routes.settings)),
];

const _variants = [
  ('bn-light', <String, Object>{}),
  ('bn-dark', <String, Object>{PrefKeys.themeMode: 'dark'}),
  ('en-light', <String, Object>{PrefKeys.lang: 'en', PrefKeys.digits: 'en'}),
  ('en-dark', <String, Object>{PrefKeys.lang: 'en', PrefKeys.digits: 'en', PrefKeys.themeMode: 'dark'}),
];

void main() {
  for (final (variant, variantPrefs) in _variants) {
    for (final screen in screens) {
      testWidgets('golden: ${screen.slug} ($variant)', (tester) async {
        await pumpApp(
          tester,
          sampleData: true,
          size: const Size(393, 852),
          prefs: {...variantPrefs, ...screen.extraPrefs, PrefKeys.displayName: 'Swapnil', PrefKeys.sampleData: true},
          onboarded: screen.onboarded,
        );
        final t = lookupAppLocalizations(Locale(containerOf(tester).read(settingsProvider).lang.name));
        await screen.open(tester, t);

        // Let any animation finish so the capture is stable.
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('_baselines/${screen.slug}-$variant.png'),
        );
      }, tags: ['golden']);
    }
  }
}
