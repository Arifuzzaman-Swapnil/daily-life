// Riverpod access to the money data (finance, salary, savings, shop credit) and
// the Finance screen's own state. Every value comes from a DAO stream, so a
// write anywhere updates every screen showing it.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/daos/finance_dao.dart';
import '../../core/db/daos/salary_dao.dart';
import '../../core/db/daos/savings_dao.dart';
import '../../core/db/daos/shop_dao.dart';
import '../../core/db/db_providers.dart';
import '../../core/format/format_provider.dart';
import 'categories.dart';

/// Today (local midnight) from the injectable clock.
DateTime todayFrom(Ref ref) => dateOnly(ref.read(clockProvider)());

/// The 1st of the current month.
DateTime currentMonthFrom(Ref ref) {
  final t = ref.read(clockProvider)();
  return DateTime(t.year, t.month);
}

// ---------------------------------------------------------------- UI state

/// The month Finance (and, from step 5, Home) shows. Starts at the current
/// month; goes back at most 11 months and not past the current month.
final selectedMonthProvider = NotifierProvider<SelectedMonth, DateTime>(SelectedMonth.new);

class SelectedMonth extends Notifier<DateTime> {
  @override
  DateTime build() => currentMonthFrom(ref);

  DateTime get latest => currentMonthFrom(ref);
  DateTime get earliest => DateTime(latest.year, latest.month - 11);

  bool get canGoBack => state.isAfter(earliest);
  bool get canGoForward => state.isBefore(latest);

  void back() {
    if (canGoBack) state = DateTime(state.year, state.month - 1);
  }

  void forward() {
    if (canGoForward) state = DateTime(state.year, state.month + 1);
  }

  void show(DateTime month) => state = DateTime(month.year, month.month);
}

enum FinTab { all, income, expense }

/// Date range filter inside the selected month.
enum FinRange { month, last7, today }

/// The Finance list's tab, search and filters (prototype `finTab`, `finQ`,
/// `finCat`, `finPm`, `finRange`).
@immutable
class FinFilter {
  const FinFilter({this.tab = FinTab.all, this.query = '', this.category, this.method, this.range = FinRange.month});

  final FinTab tab;
  final String query;

  /// Matched by id only, like the prototype (`other` covers both types). The
  /// type picks the label.
  final (TxType, String)? category;
  final PaymentMethod? method;
  final FinRange range;

  /// Filters shown as chips and counted on the filter button (search excluded).
  int get activeCount => (category != null ? 1 : 0) + (method != null ? 1 : 0) + (range != FinRange.month ? 1 : 0);

  FinFilter copyWith({FinTab? tab, String? query, (TxType, String)? Function()? category, PaymentMethod? Function()? method, FinRange? range}) =>
      FinFilter(
        tab: tab ?? this.tab,
        query: query ?? this.query,
        category: category != null ? category() : this.category,
        method: method != null ? method() : this.method,
        range: range ?? this.range,
      );

  /// The month's transactions (newest first) that pass every filter. Search
  /// matches title, description and category name.
  List<Txn> apply(List<Txn> month, DateTime today, String Function(Txn) categoryLabel) {
    final q = query.trim().toLowerCase();
    final todayKey = dayKey(today);
    final weekStart = dayKey(DateTime(today.year, today.month, today.day - 6));
    return [
      for (final x in month)
        if ((tab == FinTab.all || x.type.name == tab.name) &&
            (category == null || x.categoryId == category!.$2) &&
            (method == null || x.paymentMethod == method) &&
            switch (range) {
              FinRange.month => true,
              FinRange.today => dayKey(x.date) == todayKey,
              FinRange.last7 => dayKey(x.date).compareTo(weekStart) >= 0 && dayKey(x.date).compareTo(todayKey) <= 0,
            } &&
            (q.isEmpty || '${x.title} ${x.description} ${categoryLabel(x)}'.toLowerCase().contains(q)))
          x,
    ];
  }
}

final finFilterProvider = NotifierProvider<FinFilterController, FinFilter>(FinFilterController.new);

class FinFilterController extends Notifier<FinFilter> {
  @override
  FinFilter build() => const FinFilter();

  /// Switching tabs drops the category filter (its list depends on the tab).
  void setTab(FinTab tab) => state = state.copyWith(tab: tab, category: () => null);

  void setQuery(String q) => state = state.copyWith(query: q);

  /// Tapping the selected chip again clears it.
  void toggleCategory((TxType, String) c) => state = state.copyWith(category: () => state.category?.$2 == c.$2 ? null : c);

  void toggleMethod(PaymentMethod m) => state = state.copyWith(method: () => state.method == m ? null : m);

  void setRange(FinRange r) => state = state.copyWith(range: r);

  void clearCategory() => state = state.copyWith(category: () => null);

  void clearMethod() => state = state.copyWith(method: () => null);

  /// "Clear filters" / "Reset": search and every filter, keeping the tab.
  void clearAll() => state = FinFilter(tab: state.tab);
}

// ---------------------------------------------------------------- finance data

final monthTotalsProvider = StreamProvider.family<MonthTotals, DateTime>(
  (ref, month) => ref.watch(financeDaoProvider).watchMonthTotals(month),
);

/// A month's transactions, newest first.
final monthTransactionsProvider = StreamProvider.family<List<Txn>, DateTime>(
  (ref, month) => ref.watch(financeDaoProvider).watchTransactions(range: DayRange.month(month)),
);

/// Whether any transaction exists at all (Finance's "no transactions yet").
final hasTransactionsProvider = StreamProvider<bool>(
  (ref) => ref.watch(financeDaoProvider).watchRecent(limit: 1).map((l) => l.isNotEmpty),
);

final transactionProvider = StreamProvider.autoDispose.family<Txn?, String>(
  (ref, id) => ref.watch(financeDaoProvider).watchTransaction(id),
);

final _categoriesProvider = StreamProvider.family<List<TxCategory>, TxType>(
  (ref, type) => ref.watch(financeDaoProvider).watchCategories(type, includeSystem: true),
);

/// Every category; [CategoryBook.empty] until both types have loaded.
final categoryBookProvider = Provider<CategoryBook>((ref) {
  final income = ref.watch(_categoriesProvider(TxType.income)).value;
  final expense = ref.watch(_categoriesProvider(TxType.expense)).value;
  if (income == null || expense == null) return CategoryBook.empty;
  return CategoryBook([...income, ...expense]);
});

/// Transactions per (type, category) this month (Categories screen).
final categoryUsageProvider = StreamProvider<Map<(TxType, String), int>>(
  (ref) => ref.watch(financeDaoProvider).watchCategoryUsage(DayRange.month(currentMonthFrom(ref))),
);

/// Totals of the last [count] months up to the current one, oldest first.
final monthlySeriesProvider = StreamProvider.family<List<MonthTotals>, int>(
  (ref, count) => ref.watch(financeDaoProvider).watchMonthlySeries(currentMonthFrom(ref), count),
);

// ---------------------------------------------------------------- salary

final salaryConfigProvider = StreamProvider<SalaryConfig>((ref) => ref.watch(salaryDaoProvider).watchSettings());

final salaryHistoryProvider = StreamProvider<List<SalaryHistoryItem>>((ref) => ref.watch(salaryDaoProvider).watchHistory());

final allocationsProvider = StreamProvider<List<Allocation>>((ref) => ref.watch(salaryDaoProvider).watchAllocations());

/// This month's spending per allocation id.
final allocationSpendingProvider = StreamProvider<Map<String, int>>(
  (ref) => ref.watch(salaryDaoProvider).watchAllocationSpending(currentMonthFrom(ref)),
);

// ---------------------------------------------------------------- savings

final savingsTotalProvider = StreamProvider<int>((ref) => ref.watch(savingsDaoProvider).watchTotal());

/// This year's deposits and withdrawals (Savings hero).
final savingsFlowsProvider = StreamProvider<({int deposits, int withdrawals})>(
  (ref) => ref.watch(savingsDaoProvider).watchFlows(DayRange.year(todayFrom(ref))),
);

final savingsEntriesProvider = StreamProvider<List<SavingsEntry>>((ref) => ref.watch(savingsDaoProvider).watchEntries());

final savingsGoalsProvider = StreamProvider<List<SavingsGoalProgress>>((ref) => ref.watch(savingsDaoProvider).watchGoals());

/// Savings balance at the end of each of the last 6 months, oldest first.
final savingsGrowthProvider = StreamProvider<List<(DateTime, int)>>(
  (ref) => ref.watch(savingsDaoProvider).watchBalanceHistory(currentMonthFrom(ref), 6),
);

// ---------------------------------------------------------------- shop credit

final shopsProvider = StreamProvider<List<ShopSummary>>((ref) => ref.watch(shopDaoProvider).watchShops());

final shopDueProvider = StreamProvider<({int total, int shops})>((ref) => ref.watch(shopDaoProvider).watchTotalDue());

/// A shop's history with this month's summary; null once deleted.
final shopDetailProvider = StreamProvider.autoDispose.family<ShopDetail?, String>(
  (ref, id) => ref.watch(shopDaoProvider).watchDetail(id, currentMonthFrom(ref)),
);
