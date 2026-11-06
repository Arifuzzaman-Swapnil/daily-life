import 'package:dailylife/app.dart';
import 'package:dailylife/core/db/app_database.dart';
import 'package:dailylife/core/db/db_providers.dart';
import 'package:dailylife/core/format/format_provider.dart';
import 'package:dailylife/core/prefs/app_settings.dart';
import 'package:dailylife/core/widgets/dl_app_bar.dart';
import 'package:dailylife/core/widgets/dl_bottom_nav.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The prototype's fixed "today".
final kToday = DateTime(2026, 11, 6, 9, 30);

/// An empty in-memory database (built-in categories only).
AppDatabase memoryDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

/// Pumps the whole app on a 393×852 phone with fresh preferences, an empty
/// in-memory database and a pinned clock.
Future<void> pumpApp(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final db = memoryDatabase();
  addTearDown(db.close);
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
}

ProviderContainer containerOf(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(DailyLifeApp)));

/// A label inside the bottom nav.
Finder navLabel(String text) => find.descendant(of: find.byType(DLBottomNav), matching: find.text(text));

/// The title of the visible root tab.
Finder titleBar(String text) => find.descendant(of: find.byType(DLAppBar), matching: find.text(text));
