// Shared Work pieces: status and priority labels and tones, the task card on
// the Work tab, the timeline card in the work history, and a ticker that
// rebuilds every second while the timer runs.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';
import '../../core/format/dl_format_more.dart';
import '../../core/format/format_provider.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import 'work_providers.dart';

/// Status label (prototype `stInfo`).
String statusLabel(AppLocalizations t, TaskStatus s) => switch (s) {
      TaskStatus.todo => t.notStarted,
      TaskStatus.inProgress => t.inProgress,
      TaskStatus.done => t.completed,
      TaskStatus.onHold => t.onHold,
    };

DLTone statusTone(TaskStatus s) => switch (s) {
      TaskStatus.todo => DLTone.neutral,
      TaskStatus.inProgress => DLTone.accent,
      TaskStatus.done => DLTone.success,
      TaskStatus.onHold => DLTone.warning,
    };

/// The history timeline's dot (prototype `nd`).
Color statusDot(DLColors c, TaskStatus s) => switch (s) {
      TaskStatus.todo => c.borderStrong,
      TaskStatus.inProgress => c.accent,
      TaskStatus.done => c.success,
      TaskStatus.onHold => c.warning,
    };

String priorityLabel(AppLocalizations t, PriorityLevel p) => switch (p) {
      PriorityLevel.high => t.high,
      PriorityLevel.medium => t.medium,
      PriorityLevel.low => t.low,
    };

DLTone priorityTone(PriorityLevel p) => switch (p) {
      PriorityLevel.high => DLTone.danger,
      PriorityLevel.medium => DLTone.warning,
      PriorityLevel.low => DLTone.neutral,
    };

/// The priority flag's colour on a task card (prototype `exp` / `wat` / `ts`).
Color priorityFlag(DLColors c, PriorityLevel p) => switch (p) {
      PriorityLevel.high => c.dangerText,
      PriorityLevel.medium => c.warningText,
      PriorityLevel.low => c.textSecondary,
    };

/// Project icon tones, by position (prototype `pc`).
const projectTones = [DLTone.accent, DLTone.teal, DLTone.warning, DLTone.success, DLTone.neutral];

/// A project's name, or "—" for a task without one.
String projectName(List<Project> projects, String? id) => projects.where((p) => p.id == id).firstOrNull?.name ?? '—';

/// Sets a task's status; marking it done says so (prototype `setTaskStatus`).
Future<void> setTaskStatus(BuildContext context, WidgetRef ref, String id, TaskStatus status) async {
  final t = AppLocalizations.of(context);
  await ref.read(workDaoProvider).setStatus(id, status);
  if (status == TaskStatus.done && context.mounted) DLToast.show(context, t.taskDone);
}

/// A task on the Work tab (prototype `WK.tasks`): a done checkbox, the title,
/// project / status tags and the time, and the priority flag.
class TaskCard extends ConsumerWidget {
  const TaskCard({super.key, required this.task, required this.projectName, required this.onOpen});

  final Task task;
  final String projectName;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final done = task.status == TaskStatus.done;
    return DLCard(
      padding: const EdgeInsets.fromLTRB(DLSpace.s1, DLSpace.s2, DLSpace.s3, DLSpace.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DLCheckbox(
            value: done,
            semanticLabel: task.title,
            onChanged: (v) => setTaskStatus(context, ref, task.id, v ? TaskStatus.done : TaskStatus.todo),
          ),
          Expanded(
            child: DLPressable(
              onTap: onOpen,
              scaleOnPress: false,
              child: Padding(
                padding: const EdgeInsets.only(top: DLSpace.s3, left: DLSpace.s1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title, style: DLText.textBodyLg.copyWith(color: done ? c.textSecondary : c.textPrimary)),
                    const SizedBox(height: DLSpace.s1),
                    Wrap(
                      spacing: DLSpace.s2,
                      runSpacing: DLSpace.s1,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        DLTag(label: projectName),
                        DLTag(label: statusLabel(t, task.status), tone: statusTone(task.status)),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(DLIcons.clock, size: 16, color: c.textSecondary),
                            const SizedBox(width: DLSpace.s1),
                            Flexible(
                              child: Text(
                                '${f.time(task.startTime)} – ${f.time(task.endTime)}',
                                style: DLText.textBodySm.copyWith(color: c.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14, left: DLSpace.s2),
            child: Semantics(
              label: '${t.priority}: ${priorityLabel(t, task.priority)}',
              child: Icon(DLIcons.flag, size: 16, color: priorityFlag(c, task.priority)),
            ),
          ),
        ],
      ),
    );
  }
}

/// A task in the work history's timeline (prototype `.tl` card): status dot on
/// the card's edge, title and logged time, then the time range, project and
/// status tags.
class TimelineTaskCard extends ConsumerWidget {
  const TimelineTaskCard({super.key, required this.task, required this.projectName, required this.onOpen});

  final Task task;
  final String projectName;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    return DLCard(
      onTap: onOpen,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, DLSpace.s3, 14, DLSpace.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: DLText.textBody.copyWith(color: c.textPrimary)),
                    ),
                    const SizedBox(width: DLSpace.s2),
                    Text(f.duration(task.spentMinutes), style: DLText.amountSm.copyWith(color: c.textSecondary)),
                  ],
                ),
                const SizedBox(height: DLSpace.s1),
                Wrap(
                  spacing: DLSpace.s2,
                  runSpacing: DLSpace.s1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('${f.time(task.startTime)} – ${f.time(task.endTime)}', style: DLText.textBodySm.copyWith(color: c.textSecondary)),
                    DLTag(label: projectName),
                    DLTag(label: statusLabel(t, task.status), tone: statusTone(task.status)),
                  ],
                ),
              ],
            ),
          ),
          PositionedDirectional(
            start: 0,
            top: 18,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: statusDot(c, task.status),
                shape: BoxShape.circle,
                border: Border.all(color: c.surface, width: 2),
                boxShadow: [BoxShadow(color: c.divider, spreadRadius: 1)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A timeline (prototype `.tl`): [children] 20 in from a 2px `divider` rule.
class WorkTimeline extends StatelessWidget {
  const WorkTimeline({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PositionedDirectional(
          start: 5,
          top: DLSpace.s2,
          bottom: DLSpace.s2,
          child: Container(width: 2, decoration: BoxDecoration(color: context.dl.divider, borderRadius: BorderRadius.circular(2))),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: DLSpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, w) in children.indexed) ...[
                if (i > 0) const SizedBox(height: DLSpace.s2),
                w,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// This week's logged hours, Saturday to Friday, today highlighted (the Work
/// tab and the productivity report; the report draws them teal).
class WeekHoursChart extends ConsumerWidget {
  const WeekHoursChart({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final f = ref.watch(formatProvider);
    final today = dateOnly(ref.watch(clockProvider)());
    final start = weekStartOf(today);
    final minutes = ref.watch(weekMinutesProvider).value ?? const <String, int>{};
    final days = [for (var i = 0; i < 7; i++) DateTime(start.year, start.month, start.day + i)];
    final hours = [for (final d in days) (minutes[dayKey(d)] ?? 0) / 60];
    return DLCard(
      child: DLBarChart(
        height: 120,
        barAreaHeight: 80,
        colors: color == null ? null : [color!],
        selectedIndex: days.indexWhere((d) => dayKey(d) == dayKey(today)),
        semanticLabel: t.weekly,
        groups: [
          for (final (i, d) in days.indexed)
            DLBarGroup(
              label: f.weekdayShort(d),
              values: [hours[i]],
              valueLabel: hours[i] > 0 ? f.oneDecimal(hours[i]) : '',
              semanticLabel: '${f.dateLong(d)}: ${f.duration(minutes[dayKey(d)] ?? 0)}',
            ),
        ],
      ),
    );
  }
}

/// Rebuilds [builder] every second while [active] (the running timer's clock).
class Ticking extends StatefulWidget {
  const Ticking({super.key, required this.active, required this.builder});

  final bool active;
  final WidgetBuilder builder;

  @override
  State<Ticking> createState() => _TickingState();
}

class _TickingState extends State<Ticking> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(Ticking oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.active) {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
