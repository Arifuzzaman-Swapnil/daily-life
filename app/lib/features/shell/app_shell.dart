import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/dl_bottom_nav.dart';

/// Hosts the 5 root tabs and the navy bottom nav. Each tab keeps its own
/// navigation stack (StatefulShellRoute.indexedStack).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      // The nav has rounded top corners; let the page ground show behind them.
      extendBody: true,
      bottomNavigationBar: DLBottomNav(
        currentIndex: shell.currentIndex,
        // Tapping the active tab again returns to that tab's root.
        onSelect: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
      ),
    );
  }
}
