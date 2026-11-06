// Riverpod access to the calendar's events and the Calendar tab's own state
// (view, selected day, shown month — prototype `calView`, `calSel`, `calYM`).
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';
import '../finance/money_providers.dart';

/// Every event, by start date and time. Repeats are expanded with
/// `eventsOn` / `eventOccursOn` (event_rules.dart).
final eventsProvider = StreamProvider<List<Event>>((ref) => ref.watch(calendarDaoProvider).watchEvents());

/// One event; null once deleted.
final eventProvider = StreamProvider.family<Event?, String>((ref, id) => ref.watch(calendarDaoProvider).watchEvent(id));

enum CalView { month, week, day, agenda }

@immutable
class CalendarState {
  const CalendarState({required this.view, required this.selected, required this.month});

  final CalView view;

  /// The selected day (local midnight).
  final DateTime selected;

  /// The 1st of the month the month view shows.
  final DateTime month;

  CalendarState copyWith({CalView? view, DateTime? selected, DateTime? month}) =>
      CalendarState(view: view ?? this.view, selected: selected ?? this.selected, month: month ?? this.month);
}

final calendarProvider = NotifierProvider<CalendarController, CalendarState>(CalendarController.new);

class CalendarController extends Notifier<CalendarState> {
  @override
  CalendarState build() {
    final today = todayFrom(ref);
    return CalendarState(view: CalView.month, selected: today, month: DateTime(today.year, today.month));
  }

  void setView(CalView v) => state = state.copyWith(view: v);

  /// Selects [day] and shows its month.
  void select(DateTime day) {
    final d = dateOnly(day);
    state = state.copyWith(selected: d, month: DateTime(d.year, d.month));
  }

  void today() => select(todayFrom(ref));

  /// Month view: the shown month moves; the selection stays.
  void shiftMonth(int by) => state = state.copyWith(month: DateTime(state.month.year, state.month.month + by));

  /// Week and day views: the selection moves by [days].
  void shiftDays(int days) => select(DateTime(state.selected.year, state.selected.month, state.selected.day + days));

  /// Home's tiles: today's day view (prototype `toCal`).
  void showToday(CalView view) {
    today();
    setView(view);
  }
}
