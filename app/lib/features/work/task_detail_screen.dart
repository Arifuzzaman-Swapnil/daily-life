import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';
import '../../core/format/dl_format_more.dart';
import '../../core/format/format_provider.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import 'work_providers.dart';
import 'work_timer.dart';
import 'work_ui.dart';

/// Task details (prototype `taskDetail`, screenshot 32): change status, the
/// facts, start the timer on it, mark it complete; edit and delete.
class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.id});

  final String id;

  Future<void> _delete(BuildContext context, WidgetRef ref, Task k) async {
    final t = AppLocalizations.of(context);
    final ok = await showDLConfirm(context, title: t.delTaskQ, body: k.title);
    if (!ok || !context.mounted) return;
    await ref.read(workDaoProvider).deleteTask(k.id);
    if (!context.mounted) return;
    DLToast.show(context, t.taskDeleted);
    popOr(context, Routes.work);
  }

  /// Opens the timer on this task. While the timer is running or paused on
  /// another task, it stays on that task (the task can't change mid-run).
  Future<void> _timer(BuildContext context, WidgetRef ref, Task k) async {
    await ref.read(workTimerProvider).pickTask(k.id);
    if (context.mounted) context.push(Routes.timer);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final k = ref.watch(taskProvider(id)).value;
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];

    final actions = k == null
        ? const <Widget>[]
        : [
            DLIconButton(icon: DLIcons.edit, tooltip: t.edit, onPressed: () => context.push(Routes.editTask(k.id))),
            DLIconButton(icon: DLIcons.trash, tooltip: t.del, onPressed: () => _delete(context, ref, k)),
          ];
    final appBar = DLAppBar(title: t.taskDetail, actions: actions, onLeading: () => popOr(context, Routes.work));
    if (k == null) return Scaffold(appBar: appBar, body: const SizedBox.shrink());

    final done = k.status == TaskStatus.done;
    final rows = <(String, String)>[
      (t.date, f.dateLong(k.date)),
      (t.time, '${f.time(k.startTime)} – ${f.time(k.endTime)}'),
      (t.duration, f.duration(math.max(0, minutesBetween(k.startTime, k.endTime)))),
      (t.timeSpent, f.duration(k.spentMinutes)),
      (t.status, statusLabel(t, k.status)),
      if (k.note.isNotEmpty) (t.note, k.note),
    ];

    return Scaffold(
      appBar: appBar,
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          DLCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: DLSpace.s2,
                  runSpacing: DLSpace.s1,
                  children: [
                    DLTag(label: projectName(projects, k.projectId)),
                    DLTag(label: priorityLabel(t, k.priority), tone: priorityTone(k.priority)),
                  ],
                ),
                const SizedBox(height: DLSpace.s2),
                Text(k.title, style: DLText.textH2.copyWith(color: c.textPrimary)),
                if (k.description.isNotEmpty) ...[
                  const SizedBox(height: DLSpace.s2),
                  Text(k.description, style: DLText.textBody.copyWith(color: c.textSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(height: DLSpace.s5),
          DLField(
            label: t.changeStatus,
            child: Wrap(
              spacing: DLSpace.s2,
              runSpacing: 0,
              children: [
                for (final s in TaskStatus.values)
                  DLChip(label: statusLabel(t, s), selected: s == k.status, onTap: () => setTaskStatus(context, ref, k.id, s)),
              ],
            ),
          ),
          DLList(children: [for (final (label, value) in rows) DLKeyValueRow(label: label, value: value)]),
          const SizedBox(height: DLSpace.s4),
          Row(
            children: [
              Expanded(
                child: DLButton(
                  label: t.startTimer,
                  icon: DLIcons.play,
                  variant: DLButtonVariant.secondary,
                  onPressed: () => _timer(context, ref, k),
                ),
              ),
              const SizedBox(width: DLSpace.s2),
              Expanded(
                child: DLButton(
                  label: t.markDone,
                  icon: DLIcons.check,
                  onPressed: done ? null : () => setTaskStatus(context, ref, k.id, TaskStatus.done),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
