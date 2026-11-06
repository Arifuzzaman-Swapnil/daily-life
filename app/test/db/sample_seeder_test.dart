import 'dart:io';
import 'dart:ui' show Locale;

import 'package:dailylife/core/db/app_database.dart';
import 'package:dailylife/core/db/sample/sample_data.dart';
import 'package:dailylife/core/db/sample/sample_seeder.dart';
import 'package:dailylife/core/format/dl_format.dart';
import 'package:dailylife/core/prefs/app_settings.dart';
import 'package:dailylife/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

const assetPath = 'assets/sample_data.json';

void main() {
  final source = File(assetPath).readAsStringSync();
  final json = SampleSeeder.parse(source);
  final nov = DateTime(2026, 11);
  final today = DateTime(2026, 11, 6);

  late AppDatabase db;
  late SampleSeeder seeder;
  setUp(() {
    db = memoryDatabase();
    seeder = SampleSeeder(db, json);
  });
  tearDown(() => db.close());

  test("the bundled asset is the kit's sample data, unchanged", () {
    expect(source, File('../daily-life-kit/data/sample_data.json').readAsStringSync());
    expect(seeder.today, today);
  });

  test('built-in categories match the sample data', () async {
    final cats = json['categories'] as Map<String, dynamic>;
    for (final type in TxType.values) {
      final rows = await db.financeDao.categoriesOf(type, includeSystem: true);
      expect(rows.map((c) => (c.id, c.icon)), [for (final c in cats[type.name] as List) (c[0], c[1])], reason: type.name);
    }
  });

  test('seeds in Bengali; November matches the Finance screen', () async {
    await seeder.seed(AppLang.bn);
    expect(await db.hasAnyData(), isTrue);

    final fin = db.financeDao;
    expect(await fin.transactionsIn(), hasLength(111));
    expect((await fin.transactionById('t1'))!.title, 'অক্টোবরের বেতন');
    final t = await fin.monthTotals(nov);
    expect((t.income, t.expense, t.savingsNet, t.available), (50000, 22880, 10000, 17120));
    final month = await fin.transactionsIn(range: DayRange.month(nov));
    expect(month, hasLength(12));
    expect(month.fold(0, (sum, x) => sum + (x.type == TxType.income ? x.amount : -x.amount)), 27120);
    expect(month.first.id, 't12');

    // Hero cards: total savings ৳1,25,000, shop credit ৳1,850.
    expect(await db.savingsDao.total(), 125000);
    expect(await db.shopDao.watchTotalDue().first, (total: 1850, shops: 2));
  });

  test('seeded money records keep their business rules', () async {
    await seeder.seed(AppLang.en);

    final s1 = (await db.shopDao.watchDetail('s1', nov).first)!;
    expect(s1.shop.name, 'Mayer Doa Store');
    expect((s1.previousBalance, s1.purchases, s1.paid, s1.balance), (1200, 300, 500, 1000));
    expect(s1.entries.last.entry.transactionId, 't11');
    expect(s1.entries.last.settles, isFalse);
    expect((await db.shopDao.watchDetail('s3', nov).first)!.entries.last.settles, isTrue);

    final goals = await db.savingsDao.goals();
    expect(goals.map((g) => (g.goal.id, g.saved)), [('g1', 54000), ('g2', 60000), ('g3', 11000)]);

    expect(await db.salaryDao.watchAllocationSpending(nov).first, {'a1': 10000, 'a2': 4480, 'a3': 650, 'a4': 5000, 'a5': 0, 'a6': 10000});
    final settings = await db.salaryDao.settings();
    expect((settings.monthlyAmount, settings.nextExpectedDate), (40000, DateTime(2026, 12, 1)));
    final history = await db.salaryDao.watchHistory().first;
    expect(history.map((h) => (h.record.id, h.raise)), [('sl1', null), ('sl2', null), ('sl3', 2000), ('sl4', null), ('sl5', null), ('sl6', null)]);
    expect(history.first.record.transactionId, 't1');
  });

  test('seeded work, planner, health, goals, documents and inbox', () async {
    await seeder.seed(AppLang.en);

    expect((await db.workDao.watchTasksOn(today).first).map((k) => k.id), ['k1', 'k2', 'k3', 'k4']);
    final p1 = (await db.workDao.watchProjectStats().first).first;
    expect((p1.project.name, p1.tasks, p1.done, p1.minutes), ('Baselinq', 6, 4, 825));
    final timer = await db.workDao.timer();
    expect((timer.state, timer.taskId), (TimerState.idle, 'k2'));

    final events = await db.calendarDao.allEvents();
    expect(events, hasLength(9));
    final payday = events.firstWhere((e) => e.id == 'ev3');
    expect((payday.startTime, payday.repeat), (null, RepeatRule.monthly));
    expect(events.firstWhere((e) => e.id == 'ev1').reminderMinutes, 10);

    expect(await db.remindersDao.watchCounts(today).first, (today: 3, upcoming: 2, completed: 2));
    expect(await db.notesDao.watchActiveCount().first, 5);

    expect(await db.healthDao.watchWaterTotals(DayRange.lastDays(today, 7)).first, {
      '2026-10-31': 2400,
      '2026-11-01': 3000,
      '2026-11-02': 2750,
      '2026-11-03': 3200,
      '2026-11-04': 1900,
      '2026-11-05': 3000,
      '2026-11-06': 1500,
    });
    expect((await db.healthDao.watchMealsOn(today).first).map((m) => m.id), ['m1', 'm2']);
    final habits = await db.healthDao.watchHabits().first;
    expect(habits.map((h) => h.habit.name), ['Reading', 'Exercise', 'Learning', 'Walking', 'Sleep on time', 'Wake up early']);
    expect(habits.first.dayKeys, hasLength(10));

    final goals = await db.goalsDao.watchGoals().first;
    expect(goals.map((g) => g.goal.id), ['gl1', 'gl2', 'gl3', 'gl4', 'gl5']);
    expect(goals.first.percent, 50);
    expect(goals.last.percent, 100);

    final docs = await db.documentsDao.watchDocuments().first;
    expect(docs.map((d) => d.id), ['d1', 'd2', 'd3', 'd4', 'd5', 'd6']);
    expect((docs[0].sizeBytes, docs[1].sizeBytes, docs[0].filePath), (240 * 1024, 1258291, null));

    expect(await db.inboxDao.watchUnreadCount().first, 3);
  });

  test('seeding again replaces everything, in the new language', () async {
    await seeder.seed(AppLang.bn);
    await db.notesDao.deleteNote('n1');
    await seeder.seed(AppLang.en);
    expect(await db.financeDao.transactionsIn(), hasLength(111));
    expect((await db.financeDao.transactionById('t1'))!.title, 'October salary');
    expect(await db.notesDao.noteById('n1'), isNotNull);
  });

  test('relocalize switches untouched sample text and keeps edits', () async {
    await seeder.seed(AppLang.bn);
    final fin = db.financeDao;
    final t2 = (await fin.transactionById('t2'))!;
    await fin.updateTransaction(t2.copyWith(title: 'My own title'));

    expect(await seeder.relocalize(AppLang.bn, AppLang.en), greaterThan(100));
    expect((await fin.transactionById('t1'))!.title, 'October salary');
    final edited = (await fin.transactionById('t2'))!;
    expect((edited.title, edited.description), ('My own title', 'Second instalment from a freelance client'));
    expect((await db.shopDao.watchShops().first).first.shop.name, 'Mayer Doa Store');
    expect((await db.healthDao.watchHabits().first).first.habit.name, 'Reading');
    expect((await db.goalsDao.watchGoals().first).first.milestones.first.title, 'Finish the course');

    await seeder.relocalize(AppLang.en, AppLang.bn);
    expect((await fin.transactionById('t1'))!.title, 'অক্টোবরের বেতন');
    expect((await db.healthDao.watchHabits().first).first.habit.name, lookupAppLocalizations(const Locale('bn')).h_read);
    expect((await fin.transactionById('t2'))!.title, 'My own title');
  });

  test('clearing removes all data but keeps categories', () async {
    await seeder.seed(AppLang.bn);
    await db.financeDao.addCategory(TxType.expense, 'Pets');
    await SampleSeeder.clearData(db);
    expect(await db.hasAnyData(), isFalse);
    expect(await db.financeDao.categoriesOf(TxType.expense, includeSystem: true), hasLength(12));
    expect((await db.salaryDao.settings()).monthlyAmount, 0);
    expect((await db.workDao.timer()).taskId, isNull);
  });

  test('a sample-data build seeds once, in the saved language, unless turned off', () async {
    SharedPreferences.setMockInitialValues({PrefKeys.lang: 'en'});
    final prefs = await SharedPreferences.getInstance();
    final service = SampleDataService(db, loadJson: () async => source);

    expect(await service.seedOnFirstRun(prefs), isTrue);
    expect(prefs.getBool(PrefKeys.sampleData), isTrue);
    expect((await db.financeDao.transactionById('t1'))!.title, 'October salary');
    expect(await service.seedOnFirstRun(prefs), isFalse); // already has data

    await service.clear();
    await prefs.setBool(PrefKeys.sampleData, false);
    expect(await service.seedOnFirstRun(prefs), isFalse); // turned off
    expect(await db.hasAnyData(), isFalse);
  });
}
