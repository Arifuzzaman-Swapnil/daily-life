import 'package:dailylife/core/db/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  test('a new database has the built-in categories and nothing else', () async {
    final income = await db.financeDao.categoriesOf(TxType.income);
    expect(income.map((c) => c.id), ['salary', 'bonus', 'freelance', 'extra', 'business', 'other']);
    expect(income.every((c) => c.isDefault && c.name == null), isTrue);

    // The system `shop` category exists but is never offered in the picker.
    final expense = await db.financeDao.categoriesOf(TxType.expense);
    expect(expense.map((c) => c.id), ['food', 'transport', 'rent', 'shopping', 'family', 'personal', 'medical', 'ent', 'mobile', 'other']);
    final withSystem = await db.financeDao.categoriesOf(TxType.expense, includeSystem: true);
    expect(withSystem.where((c) => c.isSystem).map((c) => c.id), [kShopCategory]);

    expect(await db.hasAnyData(), isFalse);
  });

  test('salary settings and the timer start as single default rows', () async {
    final s = await db.salaryDao.settings();
    expect(s.monthlyAmount, 0);
    expect(s.nextExpectedDate, isNull);

    final t = await db.workDao.timer();
    expect(t.state, TimerState.idle);
    expect(t.taskId, isNull);
    expect(t.accumulatedMs, 0);
  });

  test('date-only columns round-trip as local midnight and store yyyy-MM-dd', () async {
    final id = await db.financeDao.addTransaction(TransactionsCompanion.insert(
      type: TxType.expense,
      title: 'Lunch',
      categoryId: 'food',
      amount: 280,
      date: DateTime(2026, 11, 6, 13, 30),
      paymentMethod: PaymentMethod.cash,
    ));
    final tx = await db.financeDao.transactionById(id);
    expect(tx!.date, DateTime(2026, 11, 6));
    final raw = await db.customSelect("SELECT date FROM transactions WHERE id = '$id'").getSingle();
    expect(raw.read<String>('date'), '2026-11-06');
  });

  test('day keys, months and ranges', () {
    expect(dayKey(DateTime(2026, 3, 9)), '2026-03-09');
    expect(monthKey(DateTime(2026, 11, 30)), '2026-11');
    expect(parseDayKey('2026-11'), DateTime(2026, 11, 1));
    final dec = DayRange.month(DateTime(2026, 12, 15));
    expect((dec.start, dec.end), ('2026-12-01', '2027-01-01'));
    final week = DayRange.lastDays(DateTime(2026, 11, 6), 7);
    expect((week.start, week.end), ('2026-10-31', '2026-11-07'));
    expect(week.contains(DateTime(2026, 11, 6, 23, 59)), isTrue);
    expect(week.contains(DateTime(2026, 11, 7)), isFalse);
  });

  test('custom weekdays are stored as a bitmask (0 = Saturday … 6 = Friday)', () async {
    final id = await db.remindersDao.addReminder(RemindersCompanion.insert(
      title: 'Gym',
      date: DateTime(2026, 11, 7),
      time: '07:00',
      priority: PriorityLevel.low,
      category: ReminderCategory.health,
      repeat: RepeatRule.custom,
      customDays: const Value({0, 2, 6}),
    ));
    expect((await db.remindersDao.reminderById(id))!.customDays, {0, 2, 6});
    final raw = await db.customSelect("SELECT custom_days FROM reminders WHERE id = '$id'").getSingle();
    expect(raw.read<int>('custom_days'), 1 | 4 | 64);
  });

  test('foreign keys: deleting a goal deletes its milestones', () async {
    final id = await db.goalsDao.addGoal(
      title: 'Learn',
      category: GoalCategory.learning,
      targetDate: DateTime(2027),
      milestoneTitles: ['a', 'b'],
    );
    expect((await db.goalsDao.watchGoal(id).first)!.milestones, hasLength(2));
    await db.goalsDao.deleteGoal(id);
    final left = await db.customSelect('SELECT COUNT(*) AS n FROM milestones').getSingle();
    expect(left.read<int>('n'), 0);
  });
}
