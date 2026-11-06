import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'salary_dao.g.dart';

/// A salary record with its raise over the previous (older) record.
class SalaryHistoryItem {
  const SalaryHistoryItem(this.record, this.raise);

  final SalaryRecord record;

  /// Amount above the previous record, or null when it isn't higher.
  final int? raise;
}

@DriftAccessor(tables: [SalaryRecords, SalarySettings, Transactions, AllocationCategories, SavingsEntries])
class SalaryDao extends DatabaseAccessor<AppDatabase> with _$SalaryDaoMixin {
  SalaryDao(super.attachedDatabase);

  // ------------------------------------------------------------ settings

  Stream<SalaryConfig> watchSettings() => (select(salarySettings)..where((s) => s.id.equals(1))).watchSingle();

  Future<SalaryConfig> settings() => (select(salarySettings)..where((s) => s.id.equals(1))).getSingle();

  Future<void> setMonthlyAmount(int amount) =>
      (update(salarySettings)..where((s) => s.id.equals(1))).write(SalarySettingsCompanion(monthlyAmount: Value(amount)));

  Future<void> setNextExpectedDate(DateTime? date) =>
      (update(salarySettings)..where((s) => s.id.equals(1))).write(SalarySettingsCompanion(nextExpectedDate: Value(date)));

  // ------------------------------------------------------------ records

  /// Newest month first.
  Stream<List<SalaryRecord>> watchRecords() => (select(salaryRecords)
        ..orderBy([(r) => OrderingTerm.desc(r.salaryMonth), (r) => OrderingTerm.desc(r.paidDate), (r) => OrderingTerm.desc(r.createdAt)]))
      .watch();

  /// Records, newest first, each with its raise over the one before it.
  Stream<List<SalaryHistoryItem>> watchHistory() => watchRecords().map((recs) => [
        for (var i = 0; i < recs.length; i++)
          SalaryHistoryItem(
            recs[i],
            i + 1 < recs.length && recs[i].amount > recs[i + 1].amount ? recs[i].amount - recs[i + 1].amount : null,
          ),
      ]);

  /// Records a salary payment: the record, an income transaction (category
  /// salary) and the new monthly amount, in one transaction. [title] is the
  /// transaction title in the current language ("November salary").
  /// Returns the record id.
  Future<String> addSalary({
    required DateTime month,
    required DateTime paidDate,
    required int amount,
    required PaymentMethod method,
    required String title,
    String note = '',
    String time = '10:00',
  }) {
    if (amount <= 0) throw ArgumentError.value(amount, 'amount', 'must be positive');
    return transaction(() async {
      final txId = newId();
      await into(transactions).insert(TransactionsCompanion.insert(
        id: Value(txId),
        type: TxType.income,
        title: title,
        categoryId: kSalaryCategory,
        amount: amount,
        date: dateOnly(paidDate),
        time: Value(time),
        paymentMethod: method,
        note: Value(note),
      ));
      final id = newId();
      await into(salaryRecords).insert(SalaryRecordsCompanion.insert(
        id: Value(id),
        salaryMonth: DateTime(month.year, month.month),
        paidDate: dateOnly(paidDate),
        amount: amount,
        method: method,
        note: Value(note),
        transactionId: Value(txId),
      ));
      await setMonthlyAmount(amount);
      return id;
    });
  }

  Future<int> deleteRecord(String id) => (delete(salaryRecords)..where((r) => r.id.equals(id))).go();

  // ------------------------------------------------------------ allocation

  Stream<List<Allocation>> watchAllocations() =>
      (select(allocationCategories)..orderBy([(a) => OrderingTerm.asc(a.sortOrder)])).watch();

  Future<List<Allocation>> allocations() => (select(allocationCategories)..orderBy([(a) => OrderingTerm.asc(a.sortOrder)])).get();

  /// Appends a row and returns its id.
  Future<String> addAllocation({String name = '', int amount = 0, String? linkedCategoryId}) async {
    final next = await customSelect(
      'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next FROM allocation_categories',
      readsFrom: {allocationCategories},
    ).getSingle();
    final id = newId();
    await into(allocationCategories).insert(AllocationCategoriesCompanion.insert(
      id: Value(id),
      name: Value(name),
      amount: Value(amount),
      linkedCategoryId: Value(linkedCategoryId),
      sortOrder: Value(next.read<int>('next')),
    ));
    return id;
  }

  /// In-place edit of a row's name and/or amount.
  Future<void> updateAllocation(String id, {String? name, int? amount}) =>
      (update(allocationCategories)..where((a) => a.id.equals(id))).write(AllocationCategoriesCompanion(
        name: name == null ? const Value.absent() : Value(name),
        amount: amount == null ? const Value.absent() : Value(amount),
      ));

  Future<int> deleteAllocation(String id) => (delete(allocationCategories)..where((a) => a.id.equals(id))).go();

  /// Drops rows with neither a name nor an amount (the prototype's Save).
  Future<int> removeEmptyAllocations() => customUpdate(
        "DELETE FROM allocation_categories WHERE trim(name) = '' AND amount = 0",
        updates: {allocationCategories},
        updateKind: UpdateKind.delete,
      );

  /// Spent in [month] per allocation id: expenses in the linked category, or
  /// for the savings row this month's net deposits (never below 0). Unlinked
  /// rows spend 0.
  Stream<Map<String, int>> watchAllocationSpending(DateTime month) {
    final r = DayRange.month(month);
    return customSelect(
      '''
SELECT a.id AS id,
  CASE
    WHEN a.linked_category_id IS NULL THEN 0
    WHEN a.linked_category_id = '$kSavingsLink' THEN MAX(0, COALESCE((
      SELECT SUM(CASE WHEN s.type = 'deposit' THEN s.amount ELSE -s.amount END)
        FROM savings_entries s WHERE s.date >= ?1 AND s.date < ?2), 0))
    ELSE COALESCE((
      SELECT SUM(t.amount) FROM transactions t
       WHERE t.type = 'expense' AND t.category_id = a.linked_category_id AND t.date >= ?1 AND t.date < ?2), 0)
  END AS spent
FROM allocation_categories a''',
      variables: [Variable.withString(r.start), Variable.withString(r.end)],
      readsFrom: {allocationCategories, transactions, savingsEntries},
    ).watch().map((rows) => {for (final row in rows) row.read<String>('id'): row.read<int>('spent')});
  }
}
