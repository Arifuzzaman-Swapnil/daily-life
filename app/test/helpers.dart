import 'dart:io';

import 'package:dailylife/app.dart';
import 'package:dailylife/core/db/app_database.dart';
import 'package:dailylife/core/db/db_providers.dart';
import 'package:dailylife/core/db/sample/sample_data.dart';
import 'package:dailylife/core/files/file_service.dart';
import 'package:dailylife/core/format/dl_format.dart';
import 'package:dailylife/core/format/format_provider.dart';
import 'package:dailylife/core/notifications/notification_scheduler.dart';
import 'package:dailylife/core/prefs/app_settings.dart';
import 'package:dailylife/core/security/biometric_service.dart';
import 'package:dailylife/core/widgets/dl_app_bar.dart';
import 'package:dailylife/core/widgets/dl_bottom_nav.dart';
import 'package:dailylife/core/widgets/dl_inputs.dart';
import 'package:dailylife/features/notifications/notification_sync.dart';
import 'package:dailylife/router.dart';
import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The prototype's fixed "today".
final kToday = DateTime(2026, 11, 6, 9, 30);

/// A phone tall enough that long screens (Finance, forms) build completely, for
/// tests about behaviour rather than layout.
const kTallPhone = Size(393, 1800);

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
/// [prefs] (Bengali by default). [clock] replaces the pinned clock, e.g. a
/// [TestClock] for the work timer. Onboarding counts as done unless
/// [onboarded] is false (first launch). Returns the database.
Future<AppDatabase> pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  bool sampleData = false,
  Size size = const Size(393, 852),
  DateTime Function()? clock,
  bool onboarded = true,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({if (onboarded) PrefKeys.onboarded: true, ...prefs});
  final sp = await SharedPreferences.getInstance();
  final db = memoryDatabase();
  // When a test fails, its widgets (and their stream listeners) stay mounted in
  // the finished fake-async zone, so close() would never complete.
  addTearDown(() => db.close().timeout(const Duration(seconds: 2), onTimeout: () {}));
  if (sampleData) {
    final lang = AppLang.values.asNameMap()[prefs[PrefKeys.lang]] ?? AppLang.bn;
    await tester.runAsync(() => SampleDataService(db, loadJson: () async => sampleJson).load(lang));
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(sp),
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock ?? (() => kToday)),
        notificationSchedulerProvider.overrideWithValue(FakeNotificationScheduler()),
        fileServiceProvider.overrideWithValue(FakeFileService()),
        biometricServiceProvider.overrideWithValue(FakeBiometricService()),
      ],
      child: const DailyLifeApp(),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

/// Records the notification plans the app hands over, instead of scheduling.
class FakeNotificationScheduler implements NotificationScheduler {
  final plans = <List<PlannedNotification>>[];

  /// The plan now pending (empty before the first one).
  List<PlannedNotification> get pending => plans.isEmpty ? const [] : plans.last;

  @override
  Future<void> init(void Function(String route) onOpen) async {}

  @override
  Future<void> replaceAll(List<PlannedNotification> plan, Map<NotifChannel, String> channelNames) async => plans.add(plan);
}

/// The fake scheduler [pumpApp] installs.
FakeNotificationScheduler notificationsOf(WidgetTester tester) =>
    containerOf(tester).read(notificationSchedulerProvider) as FakeNotificationScheduler;

/// Stands in for the device's files: the picker returns [next] (a file per
/// kind by default), storing and sharing are recorded.
class FakeFileService implements FileService {
  PickedFile? Function(DocKind kind) next = (kind) => kind == DocKind.pdf
      ? const PickedFile(path: '/picked/scan.pdf', name: 'scan_2026-11-06.pdf', size: 798720)
      : const PickedFile(path: '/picked/photo.jpg', name: 'IMG_20261106_1042.jpg', size: 1468006);
  final stored = <String>[];
  final deleted = <String?>[];
  final shared = <String>[];

  @override
  Future<PickedFile?> pick(DocKind kind) async => next(kind);

  @override
  Future<({String path, int pages})> store(PickedFile file, String id, DocKind kind) async {
    stored.add(id);
    return (path: '/app/documents/$id', pages: kind == DocKind.pdf ? 2 : 1);
  }

  @override
  Future<void> delete(String? path) async => deleted.add(path);

  @override
  Future<void> share({String? path, required String text}) async => shared.add(text);

  @override
  Future<void> shareTextFile(String fileName, String content, {required String subject}) async => shared.add('$fileName: $content');
}

/// The fake file service [pumpApp] installs.
FakeFileService filesOf(WidgetTester tester) => containerOf(tester).read(fileServiceProvider) as FakeFileService;

/// Stands in for the fingerprint prompt: [available] and the [result] of each
/// prompt are set by the test; prompts are counted.
class FakeBiometricService implements BiometricService {
  bool available = true;
  bool result = true;
  int prompts = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate({required String reason, required String title, required String hint, required String cancel}) async {
    prompts++;
    return result;
  }
}

/// The fake fingerprint service [pumpApp] installs.
FakeBiometricService biometricsOf(WidgetTester tester) => containerOf(tester).read(biometricServiceProvider) as FakeBiometricService;

/// A clock that starts at [kToday] and moves only when told to.
class TestClock {
  DateTime now = kToday;

  void advance(Duration d) => now = now.add(d);

  DateTime call() => now;
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

/// Scrolls [finder] into view (building it first if the list hasn't yet),
/// taps it and settles.
Future<void> tapOn(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) await scrollTo(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Types [text] into the field labelled [label] and settles.
Future<void> typeInto(WidgetTester tester, String label, String text) async {
  final field = fieldLabelled(label);
  if (field.evaluate().isEmpty) await scrollTo(tester, find.text(label));
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
