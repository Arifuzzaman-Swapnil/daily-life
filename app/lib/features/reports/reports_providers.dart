// What the reports read, per period. Families keyed by the period, so moving
// to another month or year starts a fresh load (the skeleton shows meanwhile).
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/daos/finance_dao.dart';
import '../../core/db/db_providers.dart';
import '../finance/money_providers.dart';

enum ReportTab { fin, prod, life }

/// A report period: one month, or a calendar year.
@immutable
class ReportPeriod {
  const ReportPeriod.month(DateTime m)
      : year = false,
        start = m;
  ReportPeriod.year(int y)
      : year = true,
        start = DateTime(y);

  final bool year;

  /// The 1st of the month, or 1 January.
  final DateTime start;

  DayRange get range => year ? DayRange.year(start) : DayRange.month(start);

  /// The months of the period.
  List<DateTime> get months => year ? [for (var m = 1; m <= 12; m++) DateTime(start.year, m)] : [start];

  @override
  bool operator ==(Object other) => other is ReportPeriod && other.year == year && other.start == start;

  @override
  int get hashCode => Object.hash(year, start);
}

/// Monthly totals for the income-vs-expense bars: the 6 months up to a month,
/// or the 12 months of a year.
final reportSeriesProvider = StreamProvider.family<List<MonthTotals>, ReportPeriod>((ref, p) {
  final last = p.year ? DateTime(p.start.year, 12) : p.start;
  return ref.watch(financeDaoProvider).watchMonthlySeries(last, p.year ? 12 : 6);
});

/// Expense per category in the period, largest first.
final reportCategoriesProvider = StreamProvider.family<List<(String, int)>, ReportPeriod>(
  (ref, p) => ref.watch(financeDaoProvider).watchExpenseByCategory(p.range),
);

/// Tasks in the period.
final reportTasksProvider = StreamProvider.family<List<Task>, ReportPeriod>(
  (ref, p) => ref.watch(workDaoProvider).watchTasksIn(p.range),
);

/// The last 7 days, oldest first (the lifestyle report).
List<DateTime> last7Days(DateTime today) => [for (var i = 6; i >= 0; i--) DateTime(today.year, today.month, today.day - i)];

/// Water per day of the last 7 days.
final weekWaterProvider = StreamProvider<Map<String, int>>(
  (ref) => ref.watch(healthDaoProvider).watchWaterTotals(DayRange.lastDays(todayFrom(ref), 7)),
);

/// Tasks of the last 7 days.
final weekTasksProvider = StreamProvider<List<Task>>(
  (ref) => ref.watch(workDaoProvider).watchTasksIn(DayRange.lastDays(todayFrom(ref), 7)),
);
