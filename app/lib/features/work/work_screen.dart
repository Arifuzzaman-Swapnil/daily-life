import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import '../../core/format/dl_format_more.dart';
import '../../core/format/format_provider.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import 'work_providers.dart';
import 'work_timer.dart';
import 'work_ui.dart';

/// The Work tab (prototype `work`, screenshot 30; empty 92): today's figures,
/// the timer, this week's hours and today's tasks.
class WorkScreen extends ConsumerWidget {
  const WorkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final today = dateOnly(ref.watch(clockProvider)());
    final tasks = ref.watch(todayTasksProvider).value;
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final bottom = MediaQuery.paddingOf(context).bottom;
    void addWork() => context.push(Routes.newTask());

    return Stack(
      children: [
        Column(
          children: [
            DLAppBar.root(
              title: t.workTitle,
              actions: [
                DLIconButton(icon: DLIcons.clock, tooltip: t.workHistory, onPressed: () => context.push(Routes.workHistory)),
                DLIconButton(icon: DLIcons.folder, tooltip: t.projects, onPressed: () => context.push(Routes.projects)),
              ],
            ),
            Expanded(
              child: ListView(
                // Room under the last card for the + button.
                padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, bottom + DLSize.fab + DLSpace.s8),
                children: [
                  Text(f.dateLong(today), style: DLText.textBody.copyWith(color: c.textSecondary)),
                  const SizedBox(height: DLSpace.s3),
                  _Stats(tasks: tasks ?? const []),
                  const SizedBox(height: DLSpace.s3),
                  _TimerHero(projects: projects),
                  const _WeekChart(),
                  DLSectionTitle(t.todayTasks, trailing: DLLinkButton(label: t.seeAll, onPressed: () => context.push(Routes.workHistory))),
                  if (tasks != null && tasks.isEmpty)
                    DLEmptyState(
                      inCard: true,
                      icon: DLIcons.briefcase,
                      title: t.noTasks,
                      body: t.noTasksSub,
                      actionLabel: t.addWork,
                      onAction: addWork,
                    )
                  else if (tasks != null)
                    for (final (i, k) in tasks.indexed) ...[
                      if (i > 0) const SizedBox(height: DLSpace.s3),
                      TaskCard(task: k, projectName: projectName(projects, k.projectId), onOpen: () => context.push(Routes.task(k.id))),
                    ],
                ],
              ),
            ),
          ],
        ),
        Positioned(right: DLSpace.s4, bottom: bottom + DLSpace.s4, child: DLFab(tooltip: t.addWork, onPressed: addWork)),
      ],
    );
  }
}

/// Today's tasks, completed, in progress / pending, and hours worked.
class _Stats extends ConsumerWidget {
  const _Stats({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final f = ref.watch(formatProvider);
    final timer = ref.watch(timerProvider).value;
    final now = ref.watch(clockProvider);
    int count(bool Function(Task k) test) => tasks.where(test).length;
    final spent = tasks.fold<int>(0, (sum, k) => sum + k.spentMinutes);

    Widget stat(IconData icon, DLTone tone, String value, String label) => _StatCard(icon: icon, tone: tone, value: value, label: label);
    Widget pair(Widget a, Widget b) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Expanded(child: a), const SizedBox(width: DLSpace.s3), Expanded(child: b)],
          ),
        );

    return Column(
      children: [
        pair(
          stat(DLIcons.briefcase, DLTone.accent, f.count(tasks.length), t.todayTasks),
          stat(DLIcons.checkCircle, DLTone.success, f.count(count((k) => k.status == TaskStatus.done)), t.completed),
        ),
        const SizedBox(height: DLSpace.s3),
        pair(
          stat(
            DLIcons.alert,
            DLTone.teal,
            '${f.count(count((k) => k.status == TaskStatus.inProgress))}/'
                '${f.count(count((k) => k.status == TaskStatus.todo || k.status == TaskStatus.onHold))}',
            '${t.inProgress} / ${t.pending}',
          ),
          // Live: includes the running timer's whole minutes.
          Ticking(
            active: timer?.state == TimerState.running,
            builder: (context) {
              final live = timer != null && timer.busy ? (timer.elapsedMs(now()) / 60000).round() : 0;
              return stat(DLIcons.clock, DLTone.warning, f.duration(spent + live), t.workHours);
            },
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.tone, required this.value, required this.label});

  final IconData icon;
  final DLTone tone;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    return DLCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DLIconChip(icon: icon, tone: tone, size: 36),
              const SizedBox(width: DLSpace.s2),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(value, maxLines: 1, style: DLText.amountLg.copyWith(color: c.textPrimary)),
                ),
              ),
            ],
          ),
          const SizedBox(height: DLSpace.s1),
          Text(label, style: DLText.textBodySm.copyWith(color: c.textSecondary)),
        ],
      ),
    );
  }
}

/// The navy timer block: state, clock, task; opens the timer.
class _TimerHero extends ConsumerWidget {
  const _TimerHero({required this.projects});

  final List<Project> projects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final now = ref.watch(clockProvider);
    final timer = ref.watch(timerProvider).value;
    final taskId = timer?.taskId;
    final task = taskId == null ? null : ref.watch(taskProvider(taskId)).value;
    final state = timer?.state ?? TimerState.idle;
    final label = switch (state) {
      TimerState.idle => t.startTimer,
      TimerState.running => t.tRunning,
      TimerState.paused => t.tPaused,
      TimerState.stopped => t.tStopped,
    };
    final taskName = task == null ? t.selectTask : '${task.title} · ${projectName(projects, task.projectId)}';

    return DLHero(
      onTap: () => context.push(Routes.timer),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: DLText.textLabel.copyWith(color: c.brandMuted)),
                Ticking(
                  active: state == TimerState.running,
                  builder: (context) => Text(
                    f.stopwatch((timer?.elapsedMs(now()) ?? 0) ~/ 1000),
                    style: DLText.amountLg.copyWith(color: c.onBrand),
                  ),
                ),
                Text(taskName, maxLines: 1, overflow: TextOverflow.ellipsis, style: DLText.textBodySm.copyWith(color: c.brandMuted)),
              ],
            ),
          ),
          const SizedBox(width: DLSpace.s3),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: c.brandHover, shape: BoxShape.circle),
            child: Icon(state == TimerState.running ? DLIcons.pause : DLIcons.play, color: c.onBrandAccent),
          ),
        ],
      ),
    );
  }
}

/// This week's logged hours under the "Weekly productivity" title.
class _WeekChart extends ConsumerWidget {
  const _WeekChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final total = (ref.watch(weekMinutesProvider).value ?? const <String, int>{}).values.fold<int>(0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DLSectionTitle(t.weekly, trailing: Text(f.duration(total), style: DLText.amountSm.copyWith(color: c.textSecondary))),
        const WeekHoursChart(),
      ],
    );
  }
}
