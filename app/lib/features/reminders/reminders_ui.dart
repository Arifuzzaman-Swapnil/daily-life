// Shared Reminders pieces: category icons, tones and labels, the done / snooze
// / on-off actions (prototype `remAct`), and the reminder card.
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

/// A category's icon and tone (prototype `remCat`).
(IconData, DLTone) reminderIcon(ReminderCategory c) => switch (c) {
      ReminderCategory.personal => (DLIcons.user, DLTone.teal),
      ReminderCategory.office => (DLIcons.briefcase, DLTone.accent),
      ReminderCategory.bill => (DLIcons.cash, DLTone.danger),
      ReminderCategory.health => (DLIcons.pulse, DLTone.success),
      ReminderCategory.other => (DLIcons.dots, DLTone.neutral),
    };

String reminderCategoryLabel(AppLocalizations t, ReminderCategory c) => switch (c) {
      ReminderCategory.personal => t.rc_personal,
      ReminderCategory.office => t.rc_office,
      ReminderCategory.bill => t.rc_bill,
      ReminderCategory.health => t.rc_health,
      ReminderCategory.other => t.rc_other,
    };

/// Not done and due before today.
bool isOverdue(Reminder r, DateTime today) => !r.done && dayKey(r.date).compareTo(dayKey(today)) < 0;

/// Snooze applies to what is due: not done, today or earlier.
bool canSnooze(Reminder r, DateTime today) => !r.done && dayKey(r.date).compareTo(dayKey(today)) <= 0;

/// Done ⇄ not done; completing says so.
Future<void> toggleReminderDone(BuildContext context, WidgetRef ref, Reminder r) async {
  final t = AppLocalizations.of(context);
  await ref.read(remindersDaoProvider).setDone(r.id, !r.done);
  if (!r.done && context.mounted) DLToast.show(context, t.remDone);
}

/// 10 minutes later.
Future<void> snoozeReminder(BuildContext context, WidgetRef ref, Reminder r) async {
  final t = AppLocalizations.of(context);
  await ref.read(remindersDaoProvider).snooze(r.id);
  if (context.mounted) DLToast.show(context, t.snoozed);
}

/// A reminder in the list (prototype `RM.items`, screenshot 51): category
/// icon, title and when, the on/off switch; priority, repeat and overdue
/// tags; done and snooze buttons.
class ReminderCard extends ConsumerWidget {
  const ReminderCard({super.key, required this.reminder});

  final Reminder reminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final today = dateOnly(ref.watch(clockProvider)());
    final r = reminder;
    final (icon, tone) = reminderIcon(r.category);
    final when = dayKey(r.date) == dayKey(today) ? f.time(r.time) : '${f.relative(r.date, today)} · ${f.time(r.time)}';
    final dim = r.done || !r.enabled;

    return DLCard(
      padding: const EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s3, DLSpace.s3, DLSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DLIconChip(icon: icon, tone: tone, size: 36),
              const SizedBox(width: DLSpace.s3),
              Expanded(
                child: DLPressable(
                  onTap: () => context.push(Routes.reminder(r.id)),
                  scaleOnPress: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.title, style: DLText.textBodyLg.copyWith(color: dim ? c.textSecondary : c.textPrimary)),
                      Text(when, style: DLText.textBodySm.copyWith(color: c.textSecondary)),
                    ],
                  ),
                ),
              ),
              DLSwitch(
                value: r.enabled,
                semanticLabel: t.enabledL,
                onChanged: (v) => ref.read(remindersDaoProvider).setEnabled(r.id, v),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 48),
            child: Wrap(
              spacing: DLSpace.s2,
              runSpacing: DLSpace.s1,
              children: [
                DLTag(label: priorityLabel(t, r.priority), tone: priorityTone(r.priority)),
                DLTag(label: repeatLabel(t, r.repeat), tone: DLTone.neutral, icon: DLIcons.repeat),
                if (isOverdue(r, today)) DLTag(label: t.overdue, tone: DLTone.danger),
              ],
            ),
          ),
          const SizedBox(height: DLSpace.s2),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 48),
            child: Wrap(
              spacing: DLSpace.s2,
              runSpacing: DLSpace.s2,
              children: [
                DLButton(
                  label: r.done ? t.markUndone : t.markDone,
                  icon: r.done ? DLIcons.undo : DLIcons.check,
                  size: DLButtonSize.sm,
                  variant: DLButtonVariant.tonal,
                  onPressed: () => toggleReminderDone(context, ref, r),
                ),
                if (canSnooze(r, today))
                  DLButton(
                    label: t.snooze,
                    icon: DLIcons.clock,
                    size: DLButtonSize.sm,
                    variant: DLButtonVariant.secondary,
                    onPressed: () => snoozeReminder(context, ref, r),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
