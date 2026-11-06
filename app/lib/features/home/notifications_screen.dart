import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import 'home_providers.dart';

/// Notifications (prototype `notifs`, screenshot 08): the inbox, newest first,
/// with a dot on unread items. Tapping one marks it read and opens where it
/// points; "Mark all read" clears every dot.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final items = ref.watch(inboxProvider).value;
    final inbox = ref.read(inboxDaoProvider);
    final tones = DLTone.values.asNameMap();

    Future<void> open(InboxItem n) async {
      final router = GoRouter.of(context);
      await inbox.markRead(n.id);
      final target = inboxDestination(n.route);
      if (target == null) return;
      if (Routes.tabs.contains(target)) {
        router.go(target);
      } else {
        router.push(target);
      }
    }

    return Scaffold(
      appBar: DLAppBar(
        title: t.notifications,
        onLeading: () => popOr(context),
        actions: [
          DLButton(
            label: t.markRead,
            size: DLButtonSize.sm,
            variant: DLButtonVariant.tonal,
            onPressed: () async {
              await inbox.markAllRead();
              if (context.mounted) DLToast.show(context, t.allRead);
            },
          ),
        ],
      ),
      body: switch (items) {
        null => const SizedBox.shrink(),
        [] => Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: DLSpace.s4),
              child: DLEmptyState(icon: DLIcons.bell, title: t.noNotif, body: t.noNotifSub),
            ),
          ),
        final list => ListView(
            padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
            children: [
              DLList(
                children: [
                  for (final n in list)
                    DLListRow(
                      leading: DLIconChip(icon: DLIcons.byKey(n.icon), tone: tones[n.tone] ?? DLTone.accent),
                      title: n.title,
                      subtitle: n.body.isEmpty ? null : n.body,
                      trailing: n.isRead ? null : DLDot(color: c.accent),
                      onTap: () => open(n),
                    ),
                ],
              ),
            ],
          ),
      },
    );
  }
}

/// Where an inbox item's `route` (a prototype screen id) leads, or null.
/// Reminders, health, notes, goals and documents live under More; their own
/// screens arrive in build step 6.
String? inboxDestination(String route) => switch (route) {
      '' => null,
      'home' => Routes.home,
      'finance' => Routes.finance,
      'calendar' => Routes.calendar,
      'work' || 'timer' || 'workHist' => Routes.work,
      'salary' => Routes.salary,
      'allocation' => Routes.allocation,
      'savings' => Routes.savings,
      'shops' => Routes.shops,
      'reports' => Routes.reports,
      'settings' => Routes.settings,
      _ => Routes.more,
    };
