import 'dart:io';

import 'package:dailylife/app.dart';
import 'package:dailylife/core/db/app_database.dart';
import 'package:dailylife/core/db/db_providers.dart';
import 'package:dailylife/core/db/sample/sample_data.dart';
import 'package:dailylife/core/format/dl_format.dart';
import 'package:dailylife/core/format/format_provider.dart';
import 'package:dailylife/core/prefs/app_settings.dart';
import 'package:dailylife/core/widgets/dl_app_bar.dart';
import 'package:dailylife/core/widgets/dl_bottom_nav.dart';
import 'package:dailylife/core/widgets/dl_inputs.dart';
import 'package:dailylife/router.dart';
import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The prototype's fixed "today".
final kToday = DateTime(2026, 11, 6, 9, 30);

/// The bundled sample data, read synchronously (widget tests run in a fake
/// async zone where real file IO never completes).
final sampleJson = File(SampleDataService.asset).readAsStringSync();

/// An empty in-memory database (built-in categories only). Streams close
/// synchronously, so a widget test ends without drift's cache timers pending.
AppDatabase memoryDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
}

/// Pumps the whole app on a phone ([size], default 393×852) with fresh
/// preferences, an in-memory database and a pinned clock. With [sampleData]
/// the database first gets the prototype's sample data, in the language of
/// [prefs] (Bengali by default). Returns the database.
Future<AppDatabase> pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  bool sampleData = false,
  Size size = const Size(393, 852),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final db = memoryDatabase();
  addTearDown(db.close);
  if (sampleData) {
    final lang = AppLang.values.asNameMap()[prefs[PrefKeys.lang]] ?? AppLang.bn;
    await tester.runAsync(() => SampleDataService(db, loadJson: () async => sampleJson).load(lang));
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(sp),
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => kToday),
      ],
      child: const DailyLifeApp(),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

ProviderContainer containerOf(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(DailyLifeApp)));

/// Pushes [location] on the app's router and settles.
Future<void> openRoute(WidgetTester tester, String location) async {
  containerOf(tester).read(routerProvider).push(location);
  await tester.pumpAndSettle();
}

/// A label inside the bottom nav.
Finder navLabel(String text) => find.descendant(of: find.byType(DLBottomNav), matching: find.text(text));

/// The title of the visible root tab.
Finder titleBar(String text) => find.descendant(of: find.byType(DLAppBar), matching: find.text(text));

/// The text input of the field labelled [label] (a `DLTextField`).
Finder fieldLabelled(String label) =>
    find.descendant(of: find.ancestor(of: find.text(label), matching: find.byType(DLField)).first, matching: find.byType(EditableText));

/// Scrolls [finder] into view, taps it and settles.
Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Types [text] into the field labelled [label] and settles.
Future<void> typeInto(WidgetTester tester, String label, String text) async {
  final field = fieldLabelled(label);
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

/// Scrolls the page's main (first vertical) list until [finder] is built and
/// visible.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  final page = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;
  await tester.scrollUntilVisible(finder, 200, scrollable: page);
  await tester.pumpAndSettle();
}
