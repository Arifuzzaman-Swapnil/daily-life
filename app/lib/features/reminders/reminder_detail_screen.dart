import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';
import '../../core/format/format_provider.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../calendar/calendar_ui.dart';
import '../work/work_ui.dart';
import 'reminders_providers.dart';
import 'reminders_ui.dart';

/// Reminder details (prototype `remDetail`, screenshot 54): the reminder as its
/// notification will look, the facts, the on/off switch, snooze and done.
class ReminderDetailScreen extends ConsumerWidget {
  const ReminderDetailScreen({super.key, required this.id});

  final String id;

  Future<void> _delete(BuildContext context, WidgetRef ref, Reminder r) async {
    final t = AppLocalizations.of(context);
    final ok = await showDLConfirm(context, title: t.delRemQ, body: r.title);
    if (!ok || !context.mounted) return;
    await ref.read(remindersDaoProvider).deleteReminder(r.id);
    if (context.mounted) popOr(context, Routes.reminders);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final today = dateOnly(ref.watch(clockProvider)());
    final r = ref.watch(reminderProvider(id)).value;

    final actions = r == null
        ? const <Widget>[]
        : [
            DLIconButton(icon: DLIcons.edit, tooltip: t.edit, onPressed: () => context.push(Routes.editReminder(r.id))),
            DLIconButton(icon: DLIcons.trash, tooltip: t.del, onPressed: () => _delete(context, ref, r)),
          ];
    final appBar = DLAppBar(title: t.remDetail, actions: actions, onLeading: () => popOr(context, Routes.reminders));
    if (r == null) return Scaffold(appBar: appBar, body: const SizedBox.shrink());

    final status = r.done
        ? t.completed
        : isOverdue(r, today)
            ? t.overdue
            : t.pending;
    final rows = <(String, String)>[
      (t.date, f.dateLong(r.date)),
      (t.time, f.time(r.time)),
      (t.repeat, repeatLabel(t, r.repeat)),
      (t.category, reminderCategoryLabel(t, r.category)),
      (t.status, status),
    ];

    return Scaffold(
      appBar: appBar,
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          // The notification preview: raised, like a system notification.
          DLCard(
            color: c.surfaceRaised,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const DLLogo(),
                    const SizedBox(width: DLSpace.s2),
                    Expanded(
                      child: Text(
                        'Daily Life · ${f.time(r.time)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DLText.textCaption.copyWith(color: c.textSecondary),
                      ),
                    ),
                    const SizedBox(width: DLSpace.s2),
                    DLTag(label: priorityLabel(t, r.priority), tone: priorityTone(r.priority)),
                  ],
                ),
                const SizedBox(height: DLSpace.s2),
                Text(r.title, style: DLText.textH3.copyWith(color: c.textPrimary)),
                if (r.description.isNotEmpty) ...[
                  const SizedBox(height: DLSpace.s1),
                  Text(r.description, style: DLText.textBody.copyWith(color: c.textSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(height: DLSpace.s3),
          DLList(
            children: [
              for (final (k, v) in rows) DLKeyValueRow(label: k, value: v),
              Padding(
                padding: const EdgeInsets.fromLTRB(DLSpace.s4, 0, DLSpace.s2, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.enabledL,
                        style: DLText.textLabel.copyWith(fontWeight: FontWeight.w400, color: c.textSecondary),
                      ),
                    ),
                    DLSwitch(
                      value: r.enabled,
                      semanticLabel: t.enabledL,
                      onChanged: (v) => ref.read(remindersDaoProvider).setEnabled(r.id, v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DLSpace.s4),
          Row(
            children: [
              Expanded(
                child: DLButton(
                  label: t.snooze,
                  icon: DLIcons.clock,
                  variant: DLButtonVariant.secondary,
                  onPressed: () => snoozeReminder(context, ref, r),
                ),
              ),
              const SizedBox(width: DLSpace.s2),
              Expanded(
                child: DLButton(
                  label: r.done ? t.markUndone : t.markDone,
                  icon: r.done ? DLIcons.undo : DLIcons.check,
                  onPressed: () => toggleReminderDone(context, ref, r),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
