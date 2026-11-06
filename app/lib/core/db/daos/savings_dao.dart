import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'savings_dao.g.dart';

/// A withdrawal larger than the savings total.
class SavingsOverdrawException implements Exception {
  const SavingsOverdrawException(this.available);

  final int available;

  @override
  String toString() => 'SavingsOverdrawException(available: $available)';
}

/// A savings goal with how much has been saved towards it.
class SavingsGoalProgress {
  const SavingsGoalProgress(this.goal, this.saved);

  final SavingsGoal goal;

  /// Deposits − withdrawals of the entries assigned to this goal.
  final int saved;

  /// 0–100 (can exceed 100 once the target is passed).
  double get percent => goal.target > 0 ? saved / goal.target * 100 : 0;
}

@DriftAccessor(tables: [SavingsEntries, SavingsGoals])
class SavingsDao extends DatabaseAccessor<AppDatabase> with _$SavingsDaoMixin {
  SavingsDao(super.attachedDatabase);

  static const _signed = "CASE WHEN type = 'deposit' THEN amount ELSE -amount END";

  // ------------------------------------------------------------ entries

  /// Newest first.
  Stream<List<SavingsEntry>> watchEntries() =>
      (select(savingsEntries)..orderBy([(e) => OrderingTerm.desc(e.date), (e) => OrderingTerm.desc(e.createdAt)])).watch();

  Selectable<int> _total() => customSelect(
        'SELECT COALESCE(SUM($_signed), 0) AS total FROM savings_entries',
        readsFrom: {savingsEntries},
      ).map((r) => r.read<int>('total'));

  /// All deposits − all withdrawals.
  Stream<int> watchTotal() => _total().watchSingle();

  Future<int> total() => _total().getSingle();

  /// Deposits and withdrawals dated in [range] (the Savings hero shows this year's).
  Stream<({int deposits, int withdrawals})> watchFlows(DayRange range) => customSelect(
        '''
SELECT COALESCE(SUM(CASE WHEN type = 'deposit' THEN amount ELSE 0 END), 0) AS deposits,
       COALESCE(SUM(CASE WHEN type = 'withdrawal' THEN amount ELSE 0 END), 0) AS withdrawals
  FROM savings_entries WHERE date >= ?1 AND date < ?2''',
        variables: [Variable.withString(range.start), Variable.withString(range.end)],
        readsFrom: {savingsEntries},
      ).watchSingle().map((r) => (deposits: r.read<int>('deposits'), withdrawals: r.read<int>('withdrawals')));

  /// The savings balance at the end of each of [count] months ending with
  /// [lastMonth], oldest first.
  Stream<List<(DateTime month, int balance)>> watchBalanceHistory(DateTime lastMonth, int count) => watchEntries().map((entries) {
        (DateTime, int) at(int monthsBack) {
          final m = DateTime(lastMonth.year, lastMonth.month - monthsBack);
          final end = DateTime(m.year, m.month + 1);
          final bal = entries
              .where((e) => e.date.isBefore(end))
              .fold(0, (sum, e) => sum + (e.type == SavingsDirection.deposit ? e.amount : -e.amount));
          return (m, bal);
        }

        return [for (var i = count - 1; i >= 0; i--) at(i)];
      });

  /// Adds a deposit or withdrawal and returns its id. A withdrawal larger than
  /// the total throws [SavingsOverdrawException] and writes nothing.
  Future<String> addEntry({
    required SavingsDirection type,
    required int amount,
    required DateTime date,
    String note = '',
    String? goalId,
  }) {
    if (amount <= 0) throw ArgumentError.value(amount, 'amount', 'must be positive');
    return transaction(() async {
      if (type == SavingsDirection.withdrawal) {
        final available = await total();
        if (amount > available) throw SavingsOverdrawException(available);
      }
      final id = newId();
      await into(savingsEntries).insert(SavingsEntriesCompanion.insert(
        id: Value(id),
        type: type,
        amount: amount,
        date: dateOnly(date),
        note: Value(note),
        goalId: Value(goalId),
      ));
      return id;
    });
  }

  Future<int> deleteEntry(String id) => (delete(savingsEntries)..where((e) => e.id.equals(id))).go();

  // ------------------------------------------------------------ goals

  Selectable<SavingsGoalProgress> _goals() => customSelect(
        '''
SELECT g.*, COALESCE((SELECT SUM($_signed) FROM savings_entries e WHERE e.goal_id = g.id), 0) AS saved
  FROM savings_goals g ORDER BY g.created_at''',
        readsFrom: {savingsGoals, savingsEntries},
      ).map((row) => SavingsGoalProgress(savingsGoals.map(row.data), row.read<int>('saved')));

  /// Goals in creation order, each with its saved amount.
  Stream<List<SavingsGoalProgress>> watchGoals() => _goals().watch();

  Future<List<SavingsGoalProgress>> goals() => _goals().get();

  Future<String> addGoal({required String name, required int target, required DateTime targetDate}) async {
    final id = newId();
    await into(savingsGoals).insert(SavingsGoalsCompanion.insert(id: Value(id), name: name, target: target, targetDate: dateOnly(targetDate)));
    return id;
  }

  Future<bool> updateGoal(SavingsGoal goal) => update(savingsGoals).replace(goal);

  /// Its entries stay in the savings total, without a goal.
  Future<int> deleteGoal(String id) => (delete(savingsGoals)..where((g) => g.id.equals(id))).go();
}
