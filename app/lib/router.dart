import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/widgets/dl_basics.dart';
import 'core/widgets/dl_icons.dart';
import 'features/more/more_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/shell/tab_placeholder.dart';
import 'l10n/app_localizations.dart';

abstract final class Routes {
  static const home = '/home';
  static const finance = '/finance';
  static const calendar = '/calendar';
  static const work = '/work';
  static const more = '/more';

  /// Full-screen pages above the shell (no bottom nav).
  static const settings = '/settings';
}

/// Built once for the app's lifetime, so locale/theme changes never reset navigation.
final routerProvider = Provider<GoRouter>((ref) {
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.home, builder: (context, state) => const _HomeTab()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.finance, builder: (context, state) => TabPlaceholder(title: AppLocalizations.of(context).finance)),
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
      GoRoute(
        path: Routes.settings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Home placeholder with the prototype's settings shortcut in the title bar.
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return TabPlaceholder(
      title: t.home,
      actions: [
        DLIconButton(icon: DLIcons.gear, tooltip: t.settings, onPressed: () => context.push(Routes.settings)),
      ],
    );
  }
}
