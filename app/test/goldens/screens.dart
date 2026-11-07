// Shared screen definitions for goldens (key screens, phone-sized) and the
// prototype tour (every kit screen, two sizes, uploaded as an artifact to
// lay side by side with daily-life-kit/screenshots/).
import 'package:dailylife/core/db/app_database.dart';
import 'package:dailylife/features/calendar/calendar_providers.dart';
import 'package:dailylife/features/health/health_providers.dart';
import 'package:dailylife/features/reminders/reminders_providers.dart';
import 'package:dailylife/features/reports/reports_providers.dart';
import 'package:dailylife/l10n/app_localizations.dart';
import 'package:dailylife/router.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// A single stop: slug matches the kit screenshot name (minus the .png).
typedef Screen = ({
  String slug,
  Map<String, Object> extraPrefs,
  bool onboarded,
  Future<void> Function(WidgetTester tester, AppLocalizations t) open,
});

Screen screen(String slug, Future<void> Function(WidgetTester tester, AppLocalizations t) open,
        {Map<String, Object> extraPrefs = const {}, bool onboarded = true}) =>
    (slug: slug, extraPrefs: extraPrefs, onboarded: onboarded, open: open);

Future<void> push(WidgetTester tester, String location) async {
  containerOf(tester).read(routerProvider).push(location);
  await tester.pumpAndSettle();
}

Future<void> go(WidgetTester tester, String location) async {
  containerOf(tester).read(routerProvider).go(location);
  await tester.pumpAndSettle();
}

/// Phone-sized key screens for the baseline golden comparison.
final List<Screen> keyScreens = [
  screen('01-welcome', (tester, t) async {}, onboarded: false),
  screen('05-home', (tester, t) => go(tester, Routes.home)),
  screen('10-finance', (tester, t) => go(tester, Routes.finance)),
  screen('14-delete-dialog', (tester, t) async {
    await push(tester, Routes.tx('t6'));
    await tester.tap(find.byTooltip(t.del));
    await tester.pumpAndSettle();
  }),
  screen('16-add-expense', (tester, t) => push(tester, Routes.newTx(TxType.expense))),
  screen('20-allocation', (tester, t) => push(tester, Routes.allocation)),
  screen('25-shop-detail', (tester, t) => push(tester, Routes.shop('s1'))),
  screen('30-work', (tester, t) => go(tester, Routes.work)),
  screen('40-calendar-month', (tester, t) async {
    await go(tester, Routes.calendar);
    containerOf(tester).read(calendarProvider.notifier).setView(CalView.month);
    await tester.pumpAndSettle();
  }),
  screen('51-reminders', (tester, t) => push(tester, Routes.reminders)),
  screen('58-health-water', (tester, t) => push(tester, Routes.healthTab(HealthTab.water))),
  screen('70-reports-financial', (tester, t) => push(tester, Routes.reportsTab(ReportTab.fin))),
  screen('80-settings', (tester, t) => push(tester, Routes.settings)),
];

/// The full tour: every kit screenshot has a stop with the matching slug. The
/// screens the goldens cover are reused. The reports loading state (73) and
/// the onboarding step pages (02–04) aren't here: they are transient or
/// controller-driven and would never settle deterministically.
final List<Screen> prototypeScreens = [
  // Onboarding
  ...keyScreens.where((s) => s.slug == '01-welcome'),

  // Home
  ...keyScreens.where((s) => s.slug == '05-home'),
  screen('08-notifications', (tester, t) => push(tester, Routes.notifications)),

  // Finance
  ...keyScreens.where((s) => s.slug == '10-finance'),
  screen('13-transaction-detail', (tester, t) => push(tester, Routes.tx('t1'))),
  ...keyScreens.where((s) => s.slug == '14-delete-dialog'),
  screen('15-add-income', (tester, t) => push(tester, Routes.newTx(TxType.income))),
  ...keyScreens.where((s) => s.slug == '16-add-expense'),
  screen('17-categories', (tester, t) => push(tester, Routes.categories)),
  screen('18-salary', (tester, t) => push(tester, Routes.salary)),
  screen('19-add-salary', (tester, t) => push(tester, Routes.addSalary)),
  ...keyScreens.where((s) => s.slug == '20-allocation'),
  screen('21-savings-goals', (tester, t) => push(tester, Routes.savings)),
  screen('24-shop-credit', (tester, t) => push(tester, Routes.shops)),
  ...keyScreens.where((s) => s.slug == '25-shop-detail'),

  // Work
  ...keyScreens.where((s) => s.slug == '30-work'),
  screen('31-add-task', (tester, t) => push(tester, Routes.newTask())),
  screen('32-task-detail', (tester, t) => push(tester, Routes.task('k1'))),
  screen('33-timer-running', (tester, t) => push(tester, Routes.timer)),
  screen('36-work-history', (tester, t) => push(tester, Routes.workHistory)),
  screen('37-projects', (tester, t) => push(tester, Routes.projects)),
  screen('38-project-detail', (tester, t) => push(tester, Routes.project('p1'))),

  // Calendar
  ...keyScreens.where((s) => s.slug == '40-calendar-month'),
  screen('41-calendar-week', (tester, t) async {
    await go(tester, Routes.calendar);
    containerOf(tester).read(calendarProvider.notifier).setView(CalView.week);
    await tester.pumpAndSettle();
  }),
  screen('42-calendar-day', (tester, t) async {
    await go(tester, Routes.calendar);
    containerOf(tester).read(calendarProvider.notifier).setView(CalView.day);
    await tester.pumpAndSettle();
  }),
  screen('43-calendar-agenda', (tester, t) async {
    await go(tester, Routes.calendar);
    containerOf(tester).read(calendarProvider.notifier).setView(CalView.agenda);
    await tester.pumpAndSettle();
  }),
  screen('44-add-event', (tester, t) => push(tester, Routes.newEvent)),
  screen('45-event-detail', (tester, t) => push(tester, Routes.event('ev1'))),

  // More
  screen('50-more', (tester, t) => go(tester, Routes.more)),
  ...keyScreens.where((s) => s.slug == '51-reminders'),
  screen('52-reminders-upcoming', (tester, t) async {
    await push(tester, Routes.reminders);
    containerOf(tester).read(remTabProvider.notifier).set(RemTab.upcoming);
    await tester.pumpAndSettle();
  }),
  screen('53-add-reminder', (tester, t) => push(tester, Routes.newReminder())),
  screen('54-reminder-detail', (tester, t) => push(tester, Routes.reminder('r1'))),
  screen('55-notebook', (tester, t) => push(tester, Routes.notes)),
  screen('56-note-editor', (tester, t) => push(tester, Routes.editNote('n1'))),
  screen('57-note-detail', (tester, t) => push(tester, Routes.note('n1'))),
  ...keyScreens.where((s) => s.slug == '58-health-water'),
  screen('59-health-food', (tester, t) => push(tester, Routes.healthTab(HealthTab.food))),
  screen('60-meal-form', (tester, t) => push(tester, Routes.editMeal('m1'))),
  screen('61-health-habits', (tester, t) => push(tester, Routes.healthTab(HealthTab.habits))),
  screen('62-habit-detail', (tester, t) => push(tester, Routes.habit('h1'))),
  screen('63-goals', (tester, t) => push(tester, Routes.goals)),
  screen('64-goal-detail', (tester, t) => push(tester, Routes.goal('gl1'))),
  screen('65-goal-form', (tester, t) => push(tester, Routes.editGoal('gl1'))),
  screen('66-documents', (tester, t) => push(tester, Routes.documents)),
  screen('67-document-detail', (tester, t) => push(tester, Routes.document('d1'))),
  screen('68-import-document', (tester, t) => push(tester, Routes.importDoc)),

  // Reports
  ...keyScreens.where((s) => s.slug == '70-reports-financial'),
  screen('71-reports-productivity', (tester, t) => push(tester, Routes.reportsTab(ReportTab.prod))),
  screen('72-reports-lifestyle', (tester, t) => push(tester, Routes.reportsTab(ReportTab.life))),

  // Settings
  ...keyScreens.where((s) => s.slug == '80-settings'),
];
