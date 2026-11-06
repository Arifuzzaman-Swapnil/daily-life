import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/db/app_database.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/calendar/event_detail_screen.dart';
import 'features/calendar/event_form_screen.dart';
import 'features/documents/documents_screen.dart';
import 'features/finance/categories_screen.dart';
import 'features/finance/finance_screen.dart';
import 'features/finance/tx_detail_screen.dart';
import 'features/finance/tx_form_screen.dart';
import 'features/goals/goal_form_screen.dart';
import 'features/goals/goals_screen.dart';
import 'features/health/habit_detail_screen.dart';
import 'features/health/health_providers.dart';
import 'features/health/health_screen.dart';
import 'features/health/meal_form_screen.dart';
import 'features/home/home_screen.dart';
import 'features/home/notifications_screen.dart';
import 'features/more/more_screen.dart';
import 'features/notes/note_detail_screen.dart';
import 'features/notes/note_editor_screen.dart';
import 'features/notes/notes_screen.dart';
import 'features/reminders/reminder_detail_screen.dart';
import 'features/reminders/reminder_form_screen.dart';
import 'features/reminders/reminders_screen.dart';
import 'features/reports/reports_providers.dart';
import 'features/reports/reports_screen.dart';
import 'features/salary/add_salary_screen.dart';
import 'features/salary/allocation_screen.dart';
import 'features/salary/salary_screen.dart';
import 'features/savings/savings_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/shop_credit/shop_detail_screen.dart';
import 'features/shop_credit/shops_screen.dart';
import 'features/work/projects_screen.dart';
import 'features/work/task_detail_screen.dart';
import 'features/work/task_form_screen.dart';
import 'features/work/timer_screen.dart';
import 'features/work/work_history_screen.dart';
import 'features/work/work_screen.dart';

abstract final class Routes {
  static const home = '/home';
  static const finance = '/finance';
  static const calendar = '/calendar';
  static const work = '/work';
  static const more = '/more';

  /// The 5 root tabs: reached with `go`, everything else with `push`.
  static const tabs = {home, finance, calendar, work, more};

  // Full-screen pages above the shell (no bottom nav).
  static const settings = '/settings';
  static const notifications = '/notifications';

  /// New transaction of [type].
  static String newTx(TxType type) => '/tx/new?type=${type.name}';
  static String tx(String id) => '/tx/$id';
  static String editTx(String id) => '/tx/edit/$id';
  static const categories = '/categories';
  static const salary = '/salary';
  static const addSalary = '/salary/add';
  static const allocation = '/allocation';
  static const savings = '/savings';
  static const shops = '/shops';
  static String shop(String id) => '/shops/$id';
  static const reports = '/reports';

  // Work.
  /// New task, optionally in [projectId].
  static String newTask({String? projectId}) => projectId == null ? '/tasks/new' : '/tasks/new?project=$projectId';
  static String task(String id) => '/tasks/$id';
  static String editTask(String id) => '/tasks/edit/$id';
  static const timer = '/timer';
  static const workHistory = '/work-history';
  static const projects = '/projects';
  static String project(String id) => '/projects/$id';

  // Calendar. A new event starts on the Calendar's selected day.
  static const newEvent = '/events/new';
  static String event(String id) => '/events/$id';
  static String editEvent(String id) => '/events/edit/$id';

  // Reminders and notes.
  static const reminders = '/reminders';

  /// New reminder; from outside Reminders, saving then shows the list.
  static String newReminder({bool landOnList = false}) => landOnList ? '/reminders/new?land=1' : '/reminders/new';
  static String reminder(String id) => '/reminders/$id';
  static String editReminder(String id) => '/reminders/edit/$id';
  static const notes = '/notes';
  static const newNote = '/notes/new';
  static String note(String id) => '/notes/$id';
  static String editNote(String id) => '/notes/edit/$id';

  // Health and goals.
  static const health = '/health';
  static String healthTab(HealthTab tab) => '/health?tab=${tab.name}';
  static String newMeal(MealType type) => '/meals/new?type=${type.name}';
  static String editMeal(String id) => '/meals/edit/$id';
  static String habit(String id) => '/habits/$id';
  static const goals = '/goals';
  static const newGoal = '/goals/new';
  static String goal(String id) => '/goals/$id';
  static String editGoal(String id) => '/goals/edit/$id';

  // Documents and reports.
  static const documents = '/documents';
  static const importDoc = '/documents/new';
  static String document(String id) => '/documents/$id';
  static String viewDocument(String id) => '/documents/$id/view';
  static String reportsTab(ReportTab tab) => '/reports?tab=${tab.name}';
}

/// Built once for the app's lifetime, so locale/theme changes never reset navigation.
final routerProvider = Provider<GoRouter>((ref) {
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  GoRoute page(String path, Widget Function(GoRouterState state) build) =>
      GoRoute(path: path, parentNavigatorKey: rootNavigatorKey, builder: (context, state) => build(state));
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.home, builder: (context, state) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.finance, builder: (context, state) => const FinanceScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.calendar, builder: (context, state) => const CalendarScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.work, builder: (context, state) => const WorkScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.more, builder: (context, state) => const MoreScreen()),
          ]),
        ],
      ),
      page(Routes.settings, (_) => const SettingsScreen()),
      page(Routes.notifications, (_) => const NotificationsScreen()),
      // `/tx/new` and `/tx/edit/:id` come before `/tx/:id`.
      page('/tx/new', (s) => TxFormScreen(type: s.uri.queryParameters['type'] == TxType.income.name ? TxType.income : TxType.expense)),
      page('/tx/edit/:id', (s) => TxFormScreen.edit(id: s.pathParameters['id']!)),
      page('/tx/:id', (s) => TxDetailScreen(id: s.pathParameters['id']!)),
      page(Routes.categories, (_) => const CategoriesScreen()),
      page(Routes.addSalary, (_) => const AddSalaryScreen()),
      page(Routes.salary, (_) => const SalaryScreen()),
      page(Routes.allocation, (_) => const AllocationScreen()),
      page(Routes.savings, (_) => const SavingsScreen()),
      page('/shops/:id', (s) => ShopDetailScreen(id: s.pathParameters['id']!)),
      page(Routes.shops, (_) => const ShopsScreen()),
      page(Routes.reports, (s) => ReportsScreen(tab: ReportTab.values.asNameMap()[s.uri.queryParameters['tab']] ?? ReportTab.fin)),
      // `/tasks/new` and `/tasks/edit/:id` come before `/tasks/:id`.
      page('/tasks/new', (s) => TaskFormScreen(projectId: s.uri.queryParameters['project'])),
      page('/tasks/edit/:id', (s) => TaskFormScreen.edit(id: s.pathParameters['id']!)),
      page('/tasks/:id', (s) => TaskDetailScreen(id: s.pathParameters['id']!)),
      page(Routes.timer, (_) => const TimerScreen()),
      page(Routes.workHistory, (_) => const WorkHistoryScreen()),
      page('/projects/:id', (s) => ProjectDetailScreen(id: s.pathParameters['id']!)),
      page(Routes.projects, (_) => const ProjectsScreen()),
      // `/events/new` and `/events/edit/:id` come before `/events/:id`.
      page(Routes.newEvent, (_) => const EventFormScreen()),
      page('/events/edit/:id', (s) => EventFormScreen.edit(id: s.pathParameters['id']!)),
      page('/events/:id', (s) => EventDetailScreen(id: s.pathParameters['id']!)),
      page(Routes.reminders, (_) => const RemindersScreen()),
      page('/reminders/new', (s) => ReminderFormScreen(landOnList: s.uri.queryParameters['land'] == '1')),
      page('/reminders/edit/:id', (s) => ReminderFormScreen.edit(id: s.pathParameters['id']!)),
      page('/reminders/:id', (s) => ReminderDetailScreen(id: s.pathParameters['id']!)),
      page(Routes.notes, (_) => const NotesScreen()),
      page(Routes.newNote, (_) => const NoteEditorScreen()),
      page('/notes/edit/:id', (s) => NoteEditorScreen.edit(id: s.pathParameters['id']!)),
      page('/notes/:id', (s) => NoteDetailScreen(id: s.pathParameters['id']!)),
      page(Routes.health, (s) => HealthScreen(tab: HealthTab.values.asNameMap()[s.uri.queryParameters['tab']] ?? HealthTab.water)),
      page('/meals/new', (s) => MealFormScreen(type: MealType.values.asNameMap()[s.uri.queryParameters['type']] ?? MealType.snack)),
      page('/meals/edit/:id', (s) => MealFormScreen.edit(id: s.pathParameters['id']!)),
      page('/habits/:id', (s) => HabitDetailScreen(id: s.pathParameters['id']!)),
      page(Routes.goals, (_) => const GoalsScreen()),
      page(Routes.newGoal, (_) => const GoalFormScreen()),
      page('/goals/edit/:id', (s) => GoalFormScreen.edit(id: s.pathParameters['id']!)),
      page('/goals/:id', (s) => GoalDetailScreen(id: s.pathParameters['id']!)),
      page(Routes.documents, (_) => const DocumentsScreen()),
      page(Routes.importDoc, (_) => const ImportDocumentScreen()),
      page('/documents/:id/view', (s) => DocumentViewerScreen(id: s.pathParameters['id']!)),
      page('/documents/:id', (s) => DocumentDetailScreen(id: s.pathParameters['id']!)),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Pops the current page, or goes to [fallback] when there is nothing to pop
/// (the page was opened directly).
void popOr(BuildContext context, [String fallback = Routes.home]) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}
