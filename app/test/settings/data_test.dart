// Step 7.3: back up and restore (a round trip), import, CSV export, the
// sample-data switch, and About.
import 'dart:convert';

import 'package:dailylife/core/backup/backup_service.dart';
import 'package:dailylife/core/db/app_database.dart';
import 'package:dailylife/core/db/sample/sample_seeder.dart';
import 'package:dailylife/core/prefs/app_settings.dart';
import 'package:dailylife/core/prefs/privacy_prefs.dart';
import 'package:dailylife/core/widgets/dl_buttons.dart';
import 'package:dailylife/core/widgets/dl_card.dart';
import 'package:dailylife/features/finance/categories.dart';
import 'package:dailylife/features/settings/data_section.dart';
import 'package:dailylife/l10n/app_localizations.dart';
import 'package:dailylife/router.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

Future<void> tapRow(WidgetTester tester, String title) => tapOn(tester, find.widgetWithText(DLListRow, title));

Future<void> tapButton(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(DLButton, label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('back up, change things, restore: data and settings come back, security settings stay', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTallPhone, prefs: {PrefKeys.displayName: 'Swapnil', PrefKeys.sampleData: true});
    final before = await db.select(db.transactions).get();
    final notesBefore = await db.select(db.notes).get();
    expect(before, isNotEmpty);

    await openRoute(tester, Routes.settings);
    await scrollTo(tester, find.text('এখনো কোনো ব্যাকআপ নেই')); // the list builds lazily
    expect(find.text('এখনো কোনো ব্যাকআপ নেই'), findsOneWidget);
    await tapRow(tester, 'ব্যাকআপ নিন');
    expect(find.text('ব্যাকআপ সম্পন্ন হয়েছে'), findsOneWidget);
    expect(find.text('সর্বশেষ ব্যাকআপ: আজ'), findsOneWidget);
    final files = filesOf(tester);
    final json = files.backup!;
    expect(files.shared.last, startsWith('daily-life-backup-2026-11-06.json: '));
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    expect(decoded['format'], 'dailylife-backup');
    expect((decoded['tables'] as Map)['transactions'], hasLength(before.length));
    expect((decoded['prefs'] as Map)[PrefKeys.displayName], 'Swapnil');

    // Change things: remove every transaction, rename, hide amounts, set a PIN.
    await tester.runAsync(() => db.delete(db.transactions).go());
    final container = containerOf(tester);
    await container.read(settingsProvider.notifier).setDisplayName('Rina');
    await container.read(privacyProvider.notifier).setHideAmounts(true);
    await container.read(privacyProvider.notifier).setPin('1234');
    await tester.pumpAndSettle();
    expect(await db.select(db.transactions).get(), isEmpty);
    // The PIN isn't part of a backup.
    expect(json, isNot(contains(PrefKeys.pinHash)));

    await tester.pump(const Duration(seconds: 3)); // the toast leaves
    await tapRow(tester, 'রিস্টোর করুন');
    expect(find.text('ব্যাকআপ থেকে রিস্টোর করবেন?'), findsOneWidget);
    await tapButton(tester, 'রিস্টোর করুন');
    expect(find.text('রিস্টোর সম্পন্ন হয়েছে'), findsOneWidget);

    expect(await db.select(db.transactions).get(), hasLength(before.length));
    expect((await db.select(db.notes).get()).map((n) => n.title), notesBefore.map((n) => n.title));
    expect(container.read(settingsProvider).displayName, 'Swapnil');
    expect(container.read(privacyProvider).hideAmounts, isFalse);
    // Security settings stay as they are on this phone.
    expect(container.read(privacyProvider).hasPin, isTrue);
    expect(container.read(privacyProvider.notifier).checkPin('1234'), isTrue);
  });

  testWidgets('restore with no backup on the phone says so and changes nothing', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTallPhone);
    final count = (await db.select(db.transactions).get()).length;
    await openRoute(tester, Routes.settings);
    await tapRow(tester, 'রিস্টোর করুন');
    expect(find.text('ব্যাকআপ থেকে রিস্টোর করবেন?'), findsNothing);
    expect(find.text('এখনো কোনো ব্যাকআপ নেই'), findsNWidgets(2)); // the row and the toast
    expect(await db.select(db.transactions).get(), hasLength(count));
  });

  testWidgets('import: a file that is not a backup is refused; a backup replaces the data after asking', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTallPhone);
    final count = (await db.select(db.transactions).get()).length;
    final json = await BackupService(db, containerOf(tester).read(sharedPrefsProvider)).export(kToday);
    await tester.runAsync(() => SampleSeeder.clearData(db));
    await tester.pumpAndSettle();
    expect(await db.select(db.transactions).get(), isEmpty);

    await openRoute(tester, Routes.settings);
    final files = filesOf(tester);
    files.nextText = () => '{"hello": "world"}';
    await tapRow(tester, 'ইমপোর্ট করুন');
    expect(find.text('এটি ডেইলি লাইফের ব্যাকআপ ফাইল নয়'), findsOneWidget);
    expect(find.text('ইমপোর্ট করুন?'), findsNothing);

    // Cancelling the picker does nothing.
    await tester.pump(const Duration(seconds: 3));
    files.nextText = () => null;
    await tapRow(tester, 'ইমপোর্ট করুন');
    expect(find.text('ইমপোর্ট করুন?'), findsNothing);

    // A real backup: asked first; "Cancel" keeps the data.
    files.nextText = () => json;
    await tapRow(tester, 'ইমপোর্ট করুন');
    expect(find.text('ইমপোর্ট করুন?'), findsOneWidget);
    await tapButton(tester, 'বাতিল');
    expect(await db.select(db.transactions).get(), isEmpty);

    await tapRow(tester, 'ইমপোর্ট করুন');
    await tapButton(tester, 'ইমপোর্ট করুন');
    expect(find.text('ডেটা ইমপোর্ট হয়েছে'), findsOneWidget);
    expect(await db.select(db.transactions).get(), hasLength(count));
  });

  test('a backup from another app, format or schema is refused', () async {
    final db = memoryDatabase();
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues({});
    final service = BackupService(db, await SharedPreferences.getInstance());
    Map<String, Object?> backup({Object format = 'dailylife-backup', Object version = 1, Object? schema}) => {
          'format': format,
          'version': version,
          'schema': schema ?? db.schemaVersion,
          'prefs': <String, Object?>{},
          'tables': {'notes': <Object>[]},
        };
    expect(service.parse(jsonEncode(backup())).rowsIn('notes'), 0);
    for (final bad in [
      'not json',
      '[1, 2]',
      jsonEncode(backup(format: 'other-app')),
      jsonEncode(backup(version: 2)),
      jsonEncode(backup(schema: 99)),
      jsonEncode({...backup(), 'tables': {'notes': [1, 2]}}),
    ]) {
      expect(() => service.parse(bad), throwsA(isA<BackupFormatException>()), reason: bad);
    }
  });

  testWidgets('export: every transaction as CSV in the app language, with the real amounts', (tester) async {
    final db = await pumpApp(
      tester,
      sampleData: true,
      size: kTallPhone,
      prefs: {PrefKeys.lang: 'en', PrefKeys.digits: 'en', PrefKeys.hideAmounts: true},
    );
    final count = (await db.select(db.transactions).get()).length;
    await openRoute(tester, Routes.settings);
    await tapRow(tester, 'Export');
    expect(find.text('Exported as CSV'), findsOneWidget);
    final shared = filesOf(tester).shared.last;
    expect(shared, startsWith('daily-life-transactions-2026-11-06.csv: Date,Time,Type,Title,Category,Amount (৳),Payment method,Description,Note\n'));
    final lines = shared.split('\n');
    expect(lines, hasLength(count + 1));
    expect(shared, isNot(contains('••')));
  });

  test('transaction CSV quotes cells with commas, quotes and line breaks', () {
    final t = lookupAppLocalizations(const Locale('en'));
    final csv = transactionsCsv(t, CategoryBook.empty, [
      Txn(
        id: 'x',
        type: TxType.expense,
        title: 'Rice, oil',
        categoryId: 'food',
        amount: 1250,
        date: DateTime(2026, 11, 5),
        time: '19:30',
        paymentMethod: PaymentMethod.bkash,
        description: 'He said "fine"',
        note: 'line one\nline two',
        createdAt: DateTime(2026, 11, 5),
      ),
    ]);
    expect(csv.split('\n').first, 'Date,Time,Type,Title,Category,Amount (৳),Payment method,Description,Note');
    expect(csv, contains('2026-11-05,19:30,Expense,"Rice, oil",Other,1250,bKash,"He said ""fine""","line one\nline two"'));
  });

  testWidgets('sample data: off asks first and empties the app; on loads it again', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTallPhone, prefs: {PrefKeys.sampleData: true});
    await openRoute(tester, Routes.settings);
    await tapRow(tester, 'নমুনা ডেটা দেখান');
    expect(find.text('নমুনা ডেটা সরাবেন?'), findsOneWidget);
    await tapButton(tester, 'বাতিল');
    expect(await db.hasAnyData(), isTrue);

    await tapRow(tester, 'নমুনা ডেটা দেখান');
    await tapButton(tester, 'মুছে ফেলুন');
    expect(await db.hasAnyData(), isFalse);
    expect(containerOf(tester).read(sharedPrefsProvider).getBool(PrefKeys.sampleData), isFalse);

    // Nothing to lose now: on loads straight away.
    await tapRow(tester, 'নমুনা ডেটা দেখান');
    expect(find.text('নমুনা ডেটা দেখাবেন?'), findsNothing);
    expect(await db.hasAnyData(), isTrue);
    expect(containerOf(tester).read(sharedPrefsProvider).getBool(PrefKeys.sampleData), isTrue);
  });

  testWidgets('sample data on asks before replacing the person\'s own records', (tester) async {
    final db = await pumpApp(tester, size: kTallPhone);
    await tester.runAsync(() => db.into(db.transactions).insert(TransactionsCompanion.insert(
          type: TxType.expense,
          title: 'Lunch',
          categoryId: 'food',
          amount: 250,
          date: DateTime(2026, 11, 6),
          paymentMethod: PaymentMethod.cash,
          time: const Value('13:00'),
        )));
    await openRoute(tester, Routes.settings);
    await tapRow(tester, 'নমুনা ডেটা দেখান');
    expect(find.text('নমুনা ডেটা দেখাবেন?'), findsOneWidget);
    await tapButton(tester, 'বাতিল');
    expect((await db.select(db.transactions).get()).map((x) => x.title), ['Lunch']);
  });

  testWidgets('About shows the version and the privacy promise', (tester) async {
    await pumpApp(tester, size: kTallPhone);
    await openRoute(tester, Routes.settings);
    await scrollTo(tester, find.text('গোপনীয়তা তথ্য'));
    expect(find.text('সংস্করণ ০.১.০'), findsOneWidget);
    expect(find.text('আপনার সব তথ্য শুধু এই ফোনেই থাকে। আমরা কোনো তথ্য সংগ্রহ বা বিক্রি করি না।'), findsOneWidget);
  });
}
