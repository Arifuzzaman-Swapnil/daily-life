// Riverpod access to the Work data (tasks, projects, the timer) and the work
// history screen's own state. Every value comes from a WorkDao stream, so a
// write anywhere updates every screen showing it.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/daos/work_dao.dart';
import '../../core/db/db_providers.dart';
import '../../core/format/dl_format_more.dart';
import '../finance/money_providers.dart';

export '../home/home_providers.dart' show todayTasksProvider;

/// Projects in creation order.
final projectsProvider = StreamProvider<List<Project>>((ref) => ref.watch(workDaoProvider).watchProjects());

/// Projects with task counts and logged time.
final projectStatsProvider = StreamProvider<List<ProjectStats>>((ref) => ref.watch(workDaoProvider).watchProjectStats());

/// One task; null once deleted.
final taskProvider = StreamProvider.family<Task?, String>((ref, id) => ref.watch(workDaoProvider).watchTask(id));

/// A project's tasks, newest day first.
final projectTasksProvider =
    StreamProvider.family<List<Task>, String>((ref, id) => ref.watch(workDaoProvider).watchProjectTasks(id));

/// Logged minutes per day of the current week (Saturday first).
final weekMinutesProvider = StreamProvider<Map<String, int>>((ref) {
  final start = weekStartOf(todayFrom(ref));
  return ref.watch(workDaoProvider).watchMinutesByDay(DayRange(start, DateTime(start.year, start.month, start.day + 7)));
});

/// The single persisted timer row.
final timerProvider = StreamProvider<TimerSession>((ref) => ref.watch(workDaoProvider).watchTimer());

// ---------------------------------------------------------------- history

enum WorkView { daily, weekly, monthly }

/// The work history's period, search and project filter (prototype
/// `workView`, `workQ`, `workProj`).
@immutable
class WorkHistoryFilter {
  const WorkHistoryFilter({this.view = WorkView.weekly, this.search = '', this.projectId});

  final WorkView view;
  final String search;

  /// Null = all projects.
  final String? projectId;
}

final workHistoryFilterProvider = NotifierProvider<WorkHistoryFilterController, WorkHistoryFilter>(WorkHistoryFilterController.new);

class WorkHistoryFilterController extends Notifier<WorkHistoryFilter> {
  @override
  WorkHistoryFilter build() => const WorkHistoryFilter();

  void setView(WorkView v) => state = WorkHistoryFilter(view: v, search: state.search, projectId: state.projectId);

  void setSearch(String s) => state = WorkHistoryFilter(view: state.view, search: s, projectId: state.projectId);

  void setProject(String? id) => state = WorkHistoryFilter(view: state.view, search: state.search, projectId: id);
}

/// Tasks in the history's period: from today / the week's Saturday / the 1st
/// of the month, through tomorrow (as in the prototype), newest day first.
final workHistoryProvider = StreamProvider<List<Task>>((ref) {
  final f = ref.watch(workHistoryFilterProvider);
  final today = todayFrom(ref);
  final from = switch (f.view) {
    WorkView.daily => today,
    WorkView.weekly => weekStartOf(today),
    WorkView.monthly => DateTime(today.year, today.month),
  };
  final range = DayRange(from, DateTime(today.year, today.month, today.day + 2));
  return ref.watch(workDaoProvider).watchTasksIn(range, projectId: f.projectId, search: f.search);
});
