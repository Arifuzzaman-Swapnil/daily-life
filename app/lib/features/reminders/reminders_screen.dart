import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/dl_format_more.dart';
import '../../core/format/format_provider.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import 'reminders_providers.dart';
import 'reminders_ui.dart';

/// Reminders (prototype `reminders`, screenshots 51–52; empty 94): Today
/// (overdue included), Upcoming and Completed, each with its count.
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final f = ref.watch(formatProvider);
    final tab = ref.watch(remTabProvider);
    final counts = ref.watch(remCountsProvider).value;
    final list = ref.watch(remindersProvider).value;
    final bottom = MediaQuery.paddingOf(context).bottom;
    void add() => context.push(Routes.newReminder());

    return Scaffold(
      appBar: DLAppBar(
        title: t.reminders,
        onLeading: () => popOr(context, Routes.more),
        actions: [DLIconButton(icon: DLIcons.plus, tooltip: t.addReminder, onPressed: add)],
      ),
      floatingActionButton: DLFab(tooltip: t.addReminder, onPressed: add),
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, bottom + DLSize.fab + DLSpace.s8),
        children: [
          DLSegmentedTabs<RemTab>(
            value: tab,
            options: [
              (RemTab.today, '${t.remToday} (${f.count(counts?.today ?? 0)})'),
              (RemTab.upcoming, '${t.remUpcoming} (${f.count(counts?.upcoming ?? 0)})'),
              (RemTab.completed, '${t.remCompleted} (${f.count(counts?.completed ?? 0)})'),
            ],
            onChanged: ref.read(remTabProvider.notifier).set,
          ),
          const SizedBox(height: DLSpace.s3),
          if (list != null && list.isEmpty)
            DLEmptyState(
              inCard: true,
              icon: DLIcons.bell,
              title: t.noRem,
              body: t.noRemSub,
              actionLabel: t.addReminder,
              onAction: add,
            ),
          for (final (i, r) in (list ?? const []).indexed) ...[
            if (i > 0) const SizedBox(height: DLSpace.s3),
            ReminderCard(reminder: r),
          ],
        ],
      ),
    );
  }
}
