import 'package:dailylife/core/db/app_database.dart';
import 'package:dailylife/core/db/daos/savings_dao.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  group('savings', () {
    test('goal saved = deposits − withdrawals of its entries', () async {
      final dao = db.savingsDao;
      final laptop = await dao.addGoal(name: 'New laptop', target: 120000, targetDate: DateTime(2027, 6, 30));
      final trip = await dao.addGoal(name: 'Trip', target: 25000, targetDate: DateTime(2026, 12, 20));
      await dao.addEntry(type: SavingsDirection.deposit, amount: 1000, date: DateTime(2026, 9, 1), goalId: laptop);
      await dao.addEntry(type: SavingsDirection.deposit, amount: 2000, date: DateTime(2026, 10, 1), goalId: laptop);
      await dao.addEntry(type: SavingsDirection.withdrawal, amount: 500, date: DateTime(2026, 10, 9), goalId: laptop);
      await dao.addEntry(type: SavingsDirection.deposit, amount: 700, date: DateTime(2026, 10, 2), goalId: trip);
      await dao.addEntry(type: SavingsDirection.deposit, amount: 100, date: DateTime(2026, 11, 2));

      final goals = await dao.goals();
      expect(goals.map((g) => (g.goal.name, g.saved)), [('New laptop', 2500), ('Trip', 700)]);
      expect(goals.last.percent, closeTo(2.8, 0.001));
      expect(await dao.total(), 3300);

      final flows = await dao.watchFlows(DayRange.year(DateTime(2026))).first;
      expect(flows, (deposits: 3800, withdrawals: 500));

      final history = await dao.watchBalanceHistory(DateTime(2026, 11), 3).first;
      expect(history.map((h) => h.$2), [1000, 3200, 3300]);

      // Deleting a goal keeps its money in the total.
      await dao.deleteGoal(trip);
      expect(await dao.total(), 3300);
    });

    test('withdrawing more than the total is rejected', () async {
      final dao = db.savingsDao;
      await dao.addEntry(type: SavingsDirection.deposit, amount: 1000, date: DateTime(2026, 11, 1));
      await expectLater(
        dao.addEntry(type: SavingsDirection.withdrawal, amount: 1001, date: DateTime(2026, 11, 2)),
        throwsA(isA<SavingsOverdrawException>().having((e) => e.available, 'available', 1000)),
      );
      expect(await dao.watchEntries().first, hasLength(1));
      await dao.addEntry(type: SavingsDirection.withdrawal, amount: 1000, date: DateTime(2026, 11, 2));
      expect(await dao.total(), 0);
    });
  });

  group('salary', () {
    test('adding a salary records it, adds an income transaction and sets the monthly amount', () async {
      final dao = db.salaryDao;
      final id = await dao.addSalary(
        month: DateTime(2026, 10),
        paidDate: DateTime(2026, 11, 1),
        amount: 40000,
        method: PaymentMethod.bank,
        title: 'October salary',
      );
      final rec = (await dao.watchRecords().first).single;
      expect(rec.id, id);
      expect(rec.salaryMonth, DateTime(2026, 10));
      expect(rec.paidDate, DateTime(2026, 11, 1));

      final tx = (await db.financeDao.transactionById(rec.transactionId!))!;
      expect((tx.type, tx.categoryId, tx.amount, tx.title), (TxType.income, kSalaryCategory, 40000, 'October salary'));
      expect((await dao.settings()).monthlyAmount, 40000);
      expect((await db.financeDao.monthTotals(DateTime(2026, 11))).income, 40000);
    });

    test('history shows a raise over the previous record', () async {
      final dao = db.salaryDao;
      for (final (m, amount) in [(7, 38000), (8, 40000), (9, 40000)]) {
        await dao.addSalary(month: DateTime(2026, m), paidDate: DateTime(2026, m + 1), amount: amount, method: PaymentMethod.bank, title: 's');
      }
      final h = await dao.watchHistory().first;
      expect(h.map((x) => (monthKey(x.record.salaryMonth), x.raise)), [('2026-09', null), ('2026-08', 2000), ('2026-07', null)]);
    });

    test('allocation spending: linked category expenses, savings deposits, unlinked rows', () async {
      final dao = db.salaryDao;
      final food = await dao.addAllocation(name: 'Food', amount: 7000, linkedCategoryId: 'food');
      final savings = await dao.addAllocation(name: 'Savings', amount: 10000, linkedCategoryId: kSavingsLink);
      final misc = await dao.addAllocation(name: 'Misc', amount: 500);
      final empty = await dao.addAllocation();

      Future<void> expense(String cat, int amount, DateTime date) => db.financeDao.addTransaction(TransactionsCompanion.insert(
            type: TxType.expense,
            title: cat,
            categoryId: cat,
            amount: amount,
            date: date,
            paymentMethod: PaymentMethod.cash,
          ));
      await expense('food', 4200, DateTime(2026, 11, 2));
      await expense('food', 280, DateTime(2026, 11, 6));
      await expense('food', 9000, DateTime(2026, 10, 6)); // last month
      await db.savingsDao.addEntry(type: SavingsDirection.deposit, amount: 10000, date: DateTime(2026, 11, 2));

      final spent = await dao.watchAllocationSpending(DateTime(2026, 11)).first;
      expect(spent, {food: 4480, savings: 10000, misc: 0, empty: 0});

      await dao.updateAllocation(food, amount: 8000);
      expect((await dao.allocations()).first.amount, 8000);
      expect(await dao.removeEmptyAllocations(), 1);
      expect((await dao.allocations()).map((a) => a.id), [food, savings, misc]);
    });
  });

  test('salary settings next date can be set and cleared', () async {
    await db.salaryDao.setNextExpectedDate(DateTime(2026, 12, 1));
    expect((await db.salaryDao.settings()).nextExpectedDate, DateTime(2026, 12, 1));
    await db.salaryDao.setNextExpectedDate(null);
    expect((await db.salaryDao.settings()).nextExpectedDate, isNull);
  });
}
