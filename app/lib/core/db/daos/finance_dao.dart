import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'finance_dao.g.dart';

/// Money in and out for one month.
class MonthTotals {
  const MonthTotals({required this.month, required this.income, required this.expense, required this.savingsNet});

  /// The 1st of the month.
  final DateTime month;
  final int income;
  final int expense;

  /// Savings deposits − withdrawals dated in the month.
  final int savingsNet;

  /// Remaining (available) balance: income − expenses − net savings deposits.
  /// Savings deposits are not expenses; a month of net withdrawals counts as 0
  /// (as in the prototype).
  int get available => income - expense - (savingsNet > 0 ? savingsNet : 0);
}

/// The Finance list's filters. Empty/null = no filter.
class TxFilter {
  const TxFilter({this.type, this.categoryId, this.method, this.search = ''});

  final TxType? type;
  final String? categoryId;
  final PaymentMethod? method;

  /// Matched against title, description and note.
  final String search;
}

@DriftAccessor(tables: [Transactions, Categories, SavingsEntries])
class FinanceDao extends DatabaseAccessor<AppDatabase> with _$FinanceDaoMixin {
  FinanceDao(super.attachedDatabase);

  // ------------------------------------------------------------ transactions

  SimpleSelectStatement<$TransactionsTable, Txn> _list(DayRange? range, TxFilter filter) {
    final q = select(transactions);
    q.where((t) {
      Expression<bool> e = const Constant(true);
      if (range != null) e = e & t.date.isBiggerOrEqualValue(range.start) & t.date.isSmallerThanValue(range.end);
      if (filter.type != null) e = e & t.type.equalsValue(filter.type);
      if (filter.categoryId != null) e = e & t.categoryId.equals(filter.categoryId!);
      if (filter.method != null) e = e & t.paymentMethod.equalsValue(filter.method);
      final s = filter.search.trim();
      if (s.isNotEmpty) {
        final p = '%$s%';
        e = e & (t.title.like(p) | t.description.like(p) | t.note.like(p));
      }
      return e;
    });
    q.orderBy([
      (t) => OrderingTerm.desc(t.date),
      (t) => OrderingTerm.desc(t.time),
      (t) => OrderingTerm.desc(t.createdAt),
    ]);
    return q;
  }

  /// Transactions in [range] (all dates when null), newest first.
  Stream<List<Txn>> watchTransactions({DayRange? range, TxFilter filter = const TxFilter()}) => _list(range, filter).watch();

  Future<List<Txn>> transactionsIn({DayRange? range, TxFilter filter = const TxFilter()}) => _list(range, filter).get();

  /// The latest [limit] transactions (Home "recent").
  Stream<List<Txn>> watchRecent({int limit = 5}) => (_list(null, const TxFilter())..limit(limit)).watch();

  Future<Txn?> transactionById(String id) => (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<Txn?> watchTransaction(String id) => (select(transactions)..where((t) => t.id.equals(id))).watchSingleOrNull();

  /// Inserts [row] and returns its id.
  Future<String> addTransaction(TransactionsCompanion row) async {
    final id = row.id.present ? row.id.value : newId();
    await into(transactions).insert(row.copyWith(id: Value(id)));
    return id;
  }

  Future<bool> updateTransaction(Txn row) => update(transactions).replace(row);

  Future<int> deleteTransaction(String id) => (delete(transactions)..where((t) => t.id.equals(id))).go();

  // ------------------------------------------------------------ totals

  static const _monthTotalsSql = '''
SELECT
  COALESCE((SELECT SUM(amount) FROM transactions WHERE type = 'income' AND date >= ?1 AND date < ?2), 0) AS income,
  COALESCE((SELECT SUM(amount) FROM transactions WHERE type = 'expense' AND date >= ?1 AND date < ?2), 0) AS expense,
  COALESCE((SELECT SUM(CASE WHEN type = 'deposit' THEN amount ELSE -amount END)
            FROM savings_entries WHERE date >= ?1 AND date < ?2), 0) AS savings''';

  Selectable<MonthTotals> _monthTotals(DateTime month) {
    final r = DayRange.month(month);
    return customSelect(
      _monthTotalsSql,
      variables: [Variable.withString(r.start), Variable.withString(r.end)],
      readsFrom: {transactions, savingsEntries},
    ).map((row) => MonthTotals(
          month: DateTime(month.year, month.month),
          income: row.read<int>('income'),
          expense: row.read<int>('expense'),
          savingsNet: row.read<int>('savings'),
        ));
  }

  /// Income, expenses, net savings and the remaining balance of [month].
  Stream<MonthTotals> watchMonthTotals(DateTime month) => _monthTotals(month).watchSingle();

  Future<MonthTotals> monthTotals(DateTime month) => _monthTotals(month).getSingle();

  /// Totals for [count] months ending with [lastMonth], oldest first (charts, reports).
  Stream<List<MonthTotals>> watchMonthlySeries(DateTime lastMonth, int count) {
    final first = DateTime(lastMonth.year, lastMonth.month - count + 1);
    final r = DayRange(first, DateTime(lastMonth.year, lastMonth.month + 1));
    return customSelect(
      '''
SELECT substr(date, 1, 7) AS ym, type AS kind, SUM(amount) AS total
  FROM transactions WHERE date >= ?1 AND date < ?2 GROUP BY ym, kind
UNION ALL
SELECT substr(date, 1, 7) AS ym, 'savings' AS kind, SUM(CASE WHEN type = 'deposit' THEN amount ELSE -amount END) AS total
  FROM savings_entries WHERE date >= ?1 AND date < ?2 GROUP BY ym''',
      variables: [Variable.withString(r.start), Variable.withString(r.end)],
      readsFrom: {transactions, savingsEntries},
    ).watch().map((rows) {
      final sums = <String, Map<String, int>>{};
      for (final row in rows) {
        (sums[row.read<String>('ym')] ??= {})[row.read<String>('kind')] = row.read<int>('total');
      }
      MonthTotals at(int i) {
        final m = DateTime(first.year, first.month + i);
        final s = sums[monthKey(m)] ?? const <String, int>{};
        return MonthTotals(month: m, income: s['income'] ?? 0, expense: s['expense'] ?? 0, savingsNet: s['savings'] ?? 0);
      }

      return [for (var i = 0; i < count; i++) at(i)];
    });
  }

  /// Expense total per category id in [range], largest first.
  Stream<List<(String categoryId, int total)>> watchExpenseByCategory(DayRange range) => customSelect(
        '''
SELECT category_id, SUM(amount) AS total FROM transactions
 WHERE type = 'expense' AND date >= ?1 AND date < ?2
 GROUP BY category_id ORDER BY total DESC''',
        variables: [Variable.withString(range.start), Variable.withString(range.end)],
        readsFrom: {transactions},
      ).watch().map((rows) => [for (final r in rows) (r.read<String>('category_id'), r.read<int>('total'))]);

  // ------------------------------------------------------------ categories

  /// Categories of [type] in picker order: built-ins, then custom ones. The
  /// system `shop` category is left out unless [includeSystem].
  Stream<List<TxCategory>> watchCategories(TxType type, {bool includeSystem = false}) => _categories(type, includeSystem).watch();

  Future<List<TxCategory>> categoriesOf(TxType type, {bool includeSystem = false}) => _categories(type, includeSystem).get();

  SimpleSelectStatement<$CategoriesTable, TxCategory> _categories(TxType type, bool includeSystem) {
    final q = select(categories)..where((c) => c.type.equalsValue(type));
    if (!includeSystem) q.where((c) => c.isSystem.equals(false));
    q.orderBy([(c) => OrderingTerm.desc(c.isDefault), (c) => OrderingTerm.asc(c.sortOrder)]);
    return q;
  }

  Future<TxCategory?> category(TxType type, String id) =>
      (select(categories)..where((c) => c.type.equalsValue(type) & c.id.equals(id))).getSingleOrNull();

  /// Adds a custom category and returns its id.
  Future<String> addCategory(TxType type, String name) async {
    final id = newId();
    final next = await customSelect(
      'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next FROM categories WHERE type = ?1',
      variables: [Variable.withString(type.name)],
      readsFrom: {categories},
    ).getSingle();
    await into(categories).insert(CategoriesCompanion.insert(
      type: type,
      id: Value(id),
      name: Value(name),
      icon: 'tag',
      tone: 'accent',
      sortOrder: Value(next.read<int>('next')),
    ));
    return id;
  }

  /// Deletes a custom category. Built-ins can't be deleted. Its transactions keep
  /// the id and show as "Other".
  Future<int> deleteCategory(TxType type, String id) =>
      (delete(categories)..where((c) => c.type.equalsValue(type) & c.id.equals(id) & c.isDefault.equals(false))).go();

  /// How many transactions use each (type, category) in [range].
  Stream<Map<(TxType, String), int>> watchCategoryUsage(DayRange range) => customSelect(
        'SELECT type, category_id, COUNT(*) AS n FROM transactions WHERE date >= ?1 AND date < ?2 GROUP BY type, category_id',
        variables: [Variable.withString(range.start), Variable.withString(range.end)],
        readsFrom: {transactions},
      ).watch().map((rows) => {
            for (final r in rows) (TxType.values.byName(r.read<String>('type')), r.read<String>('category_id')): r.read<int>('n'),
          });
}
