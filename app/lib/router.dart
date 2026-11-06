import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/db/app_database.dart';
import 'features/finance/categories_screen.dart';
import 'features/finance/finance_screen.dart';
import 'features/finance/tx_detail_screen.dart';
import 'features/finance/tx_form_screen.dart';
import 'features/home/home_screen.dart';
import 'features/home/notifications_screen.dart';
import 'features/more/more_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/salary/add_salary_screen.dart';
import 'features/salary/allocation_screen.dart';
import 'features/salary/salary_screen.dart';
import 'features/savings/savings_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/shell/tab_placeholder.dart';
import 'features/shop_credit/shop_detail_screen.dart';
import 'features/shop_credit/shops_screen.dart';
import 'l10n/app_localizations.dart';

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
            GoRoute(path: Routes.calendar, builder: (context, state) => TabPlaceholder(title: AppLocalizations.of(context).calendar)),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.work, builder: (context, state) => TabPlaceholder(title: AppLocalizations.of(context).work)),
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
      page(Routes.reports, (_) => const ReportsScreen()),
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
