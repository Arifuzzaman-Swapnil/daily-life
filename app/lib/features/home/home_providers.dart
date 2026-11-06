// Riverpod access to what Home shows beyond the money providers: today's
// tasks, events, reminders, water, meals and habits, the latest transactions,
// the notification inbox, and the chart's period and selected bar. Every value
// comes from a DAO stream, so a write anywhere updates Home.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/daos/health_dao.dart';
import '../../core/db/db_providers.dart';
import '../calendar/event_rules.dart';
import '../finance/money_providers.dart';

/// The 5 newest transactions (prototype: sorted by date and time).
final recentTransactionsProvider = StreamProvider<List<Txn>>((ref) => ref.watch(financeDaoProvider).watchRecent(limit: 5));

/// Today's tasks by start time.
final todayTasksProvider = StreamProvider<List<Task>>((ref) => ref.watch(workDaoProvider).watchTasksOn(todayFrom(ref)));

/// Events happening today (repeats expanded), by start time.
final todayEventsProvider = StreamProvider<List<Event>>((ref) {
  final today = todayFrom(ref);
  return ref.watch(calendarDaoProvider).watchEvents().map((all) => eventsOn(all, today));
});

/// Reminders due today that are on and not done, by time (overdue ones belong
/// to the Reminders screen, not Home's tile).
final todayRemindersProvider = StreamProvider<List<Reminder>>((ref) {
  final today = todayFrom(ref);
  final key = dayKey(today);
  return ref
      .watch(remindersDaoProvider)
      .watchToday(today)
      .map((list) => [
            for (final r in list)
              if (r.enabled && dayKey(r.date) == key) r,
          ]);
});

/// Millilitres drunk today.
final todayWaterProvider = StreamProvider<int>(
  (ref) => ref.watch(healthDaoProvider).watchWaterOn(todayFrom(ref)).map((l) => l.fold<int>(0, (sum, w) => sum + w.ml)),
);

/// Today's meals by time.
final todayMealsProvider = StreamProvider<List<Meal>>((ref) => ref.watch(healthDaoProvider).watchMealsOn(todayFrom(ref)));

/// Every habit with its done days.
final habitsProvider = StreamProvider<List<HabitWithChecks>>((ref) => ref.watch(healthDaoProvider).watchHabits());

// ---------------------------------------------------------------- inbox

/// The notification list, newest first.
final inboxProvider = StreamProvider<List<InboxItem>>((ref) => ref.watch(inboxDaoProvider).watchItems());

final unreadCountProvider = StreamProvider<int>((ref) => ref.watch(inboxDaoProvider).watchUnreadCount());

// ---------------------------------------------------------------- chart

/// Home's income-vs-expense chart: 6 or 12 months up to the current one, and
/// the bar whose figures show above it (prototype `chartP`, `chartSel`).
@immutable
class HomeChart {
  const HomeChart({this.months = 6, this.selected});

  final int months;

  /// The 1st of the selected month; null = the current month.
  final DateTime? selected;
}

final homeChartProvider = NotifierProvider<HomeChartController, HomeChart>(HomeChartController.new);

class HomeChartController extends Notifier<HomeChart> {
  @override
  HomeChart build() => const HomeChart();

  void setMonths(int months) => state = HomeChart(months: months, selected: state.selected);

  void select(DateTime month) => state = HomeChart(months: state.months, selected: DateTime(month.year, month.month));
}
