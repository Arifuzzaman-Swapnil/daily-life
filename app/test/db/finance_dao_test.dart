import 'dart:async';

import 'package:dailylife/core/db/app_database.dart';
import 'package:dailylife/core/db/daos/finance_dao.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

final nov = DateTime(2026, 11);

TransactionsCompanion tx(TxType type, int amount, DateTime date, {String cat = 'other', String title = 'x', PaymentMethod pm = PaymentMethod.cash, String time = '12:00'}) =>
    TransactionsCompanion.insert(type: type, title: title, categoryId: cat, amount: amount, date: date, paymentMethod: pm, time: Value(time));

void main() {
  late AppDatabase db;
  late FinanceDao dao;
  setUp(() {
    db = memoryDatabase();
    dao = db.financeDao;
  });
  tearDown(() => db.close());

  test('add, read, update and delete a transaction', () async {
    final id = await dao.addTransaction(tx(TxType.expense, 450, DateTime(2026, 11, 3), cat: 'medical', title: 'Medicine'));
    var row = await dao.transactionById(id);
    expect(row!.title, 'Medicine');
    expect(row.amount, 450);
    expect(row.description, '');

    await dao.updateTransaction(row.copyWith(amount: 500, note: 'pharmacy'));
    row = await dao.transactionById(id);
    expect((row!.amount, row.note), (500, 'pharmacy'));

    expect(await dao.deleteTransaction(id), 1);
    expect(await dao.transactionById(id), isNull);
  });

  test('available balance = income − expenses − net savings deposits of the month', () async {
    await dao.addTransaction(tx(TxType.income, 50000, DateTime(2026, 11, 1), cat: 'salary'));
    await dao.addTransaction(tx(TxType.expense, 20000, DateTime(2026, 11, 2), cat: 'rent'));
    await dao.addTransaction(tx(TxType.expense, 999, DateTime(2026, 10, 31), cat: 'food')); // other month
    await db.savingsDao.addEntry(type: SavingsDirection.deposit, amount: 10000, date: DateTime(2026, 11, 3));
    await db.savingsDao.addEntry(type: SavingsDirection.deposit, amount: 7000, date: DateTime(2026, 12, 1)); // other month

    final t = await dao.monthTotals(nov);
    expect((t.income, t.expense, t.savingsNet), (50000, 20000, 10000));
    expect(t.available, 20000);

    // Savings deposits are not expenses.
    expect((await dao.transactionsIn()).where((x) => x.type == TxType.expense), hasLength(2));
  });

  test('a month of net savings withdrawals does not raise the balance', () async {
    await dao.addTransaction(tx(TxType.income, 50000, DateTime(2026, 11, 1)));
    await dao.addTransaction(tx(TxType.expense, 20000, DateTime(2026, 11, 2)));
    await db.savingsDao.addEntry(type: SavingsDirection.deposit, amount: 30000, date: DateTime(2026, 10, 2));
    await db.savingsDao.addEntry(type: SavingsDirection.withdrawal, amount: 5000, date: DateTime(2026, 11, 4));

    final t = await dao.monthTotals(nov);
    expect(t.savingsNet, -5000);
    expect(t.available, 30000);
  });

  test('month totals stream updates when a transaction is added', () async {
    final it = StreamIterator(dao.watchMonthTotals(nov));
    expect(await it.moveNext(), isTrue);
    expect(it.current.income, 0);
    await dao.addTransaction(tx(TxType.income, 1200, DateTime(2026, 11, 20)));
    expect(await it.moveNext(), isTrue);
    expect(it.current.income, 1200);
    await it.cancel();
  });

  test('list: newest first, with type, category, method and search filters', () async {
    await dao.addTransaction(tx(TxType.income, 40000, DateTime(2026, 11, 1), cat: 'salary', title: 'October salary', pm: PaymentMethod.bank, time: '10:15'));
    await dao.addTransaction(tx(TxType.expense, 600, DateTime(2026, 11, 1), cat: 'ent', title: 'Movie night', pm: PaymentMethod.card, time: '19:30'));
    await dao.addTransaction(tx(TxType.expense, 4200, DateTime(2026, 11, 2), cat: 'food', title: 'Monthly groceries', time: '17:30'));
    await dao.addTransaction(tx(TxType.expense, 7000, DateTime(2026, 10, 14), cat: 'food', title: 'Groceries'));

    final month = DayRange.month(nov);
    final all = await dao.transactionsIn(range: month);
    expect(all.map((x) => x.title), ['Monthly groceries', 'Movie night', 'October salary']);

    expect((await dao.transactionsIn(range: month, filter: const TxFilter(type: TxType.income))).map((x) => x.title), ['October salary']);
    expect((await dao.transactionsIn(filter: const TxFilter(categoryId: 'food'))), hasLength(2));
    expect((await dao.transactionsIn(filter: const TxFilter(method: PaymentMethod.card))).single.title, 'Movie night');
    expect((await dao.transactionsIn(filter: const TxFilter(search: 'GROC'))), hasLength(2));
    expect((await dao.watchRecent(limit: 2).first).map((x) => x.title), ['Monthly groceries', 'Movie night']);
  });

  test('monthly series and expenses by category', () async {
    await dao.addTransaction(tx(TxType.income, 1000, DateTime(2026, 9, 5)));
    await dao.addTransaction(tx(TxType.expense, 300, DateTime(2026, 11, 5), cat: 'food'));
    await dao.addTransaction(tx(TxType.expense, 200, DateTime(2026, 11, 6), cat: 'food'));
    await dao.addTransaction(tx(TxType.expense, 900, DateTime(2026, 11, 6), cat: 'rent'));

    final series = await dao.watchMonthlySeries(nov, 3).first;
    expect(series.map((m) => monthKey(m.month)), ['2026-09', '2026-10', '2026-11']);
    expect(series.map((m) => (m.income, m.expense)), [(1000, 0), (0, 0), (0, 1400)]);

    final byCat = await dao.watchExpenseByCategory(DayRange.month(nov)).first;
    expect(byCat, [('rent', 900), ('food', 500)]);
  });

  test('custom categories can be added and deleted; built-ins cannot', () async {
    final id = await dao.addCategory(TxType.expense, 'Pets');
    final list = await dao.categoriesOf(TxType.expense);
    expect(list.last.id, id);
    expect(list.last.name, 'Pets');
    expect(list.last.isDefault, isFalse);

    expect(await dao.deleteCategory(TxType.expense, 'food'), 0);
    expect(await dao.deleteCategory(TxType.expense, id), 1);
    expect((await dao.categoriesOf(TxType.expense)).map((c) => c.id), isNot(contains(id)));
  });

  test('category usage counts per type and id', () async {
    await dao.addTransaction(tx(TxType.expense, 1, DateTime(2026, 11, 2), cat: 'other'));
    await dao.addTransaction(tx(TxType.income, 1, DateTime(2026, 11, 2), cat: 'other'));
    await dao.addTransaction(tx(TxType.income, 1, DateTime(2026, 11, 3), cat: 'other'));
    final usage = await dao.watchCategoryUsage(DayRange.month(nov)).first;
    expect(usage[(TxType.income, 'other')], 2);
    expect(usage[(TxType.expense, 'other')], 1);
  });
}
