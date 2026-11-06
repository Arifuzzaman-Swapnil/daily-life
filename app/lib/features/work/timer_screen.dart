import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// The work timer (prototype `timer`, screenshots 33–35): pick one of today's
/// open tasks, then start → pause / resume → stop (time logged) → mark complete.
/// The ring fills over each hour.
class TimerScreen extends ConsumerWidget {
  const TimerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final now = ref.watch(clockProvider);
    final timer = ref.watch(timerProvider).value;
    final todays = ref.watch(todayTasksProvider).value ?? const <Task>[];
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final appBar = DLAppBar(title: t.timer, onLeading: () => popOr(context, Routes.work));
    if (timer == null) return Scaffold(appBar: appBar, body: const SizedBox.shrink());

    final ctl = ref.read(workTimerProvider);
    final state = timer.state;
    final busy = timer.busy;
    final taskId = timer.taskId;
    final task = taskId == null ? null : ref.watch(taskProvider(taskId)).value;
    final choices = [for (final k in todays) if (k.status != TaskStatus.done || k.id == taskId) k];
    final (ringColor, tagTone, stateLabel) = switch (state) {
      TimerState.idle => (c.accent, DLTone.neutral, t.tIdle),
      TimerState.running => (c.accent, DLTone.accent, t.tRunning),
      TimerState.paused => (c.warning, DLTone.warning, t.tPaused),
      TimerState.stopped => (c.success, DLTone.success, t.tStopped),
    };
    final canComplete = task != null && task.status != TaskStatus.done;

    Future<void> stop() async {
      final minutes = await ctl.stop();
      if (context.mounted) DLToast.show(context, t.logged(f.duration(minutes)));
    }

    Future<void> complete() async {
      final done = task != null;
      await ctl.complete();
      if (done && context.mounted) DLToast.show(context, t.taskDone);
    }

    final buttons = switch (state) {
      TimerState.idle => [DLButton(label: t.tStart, icon: DLIcons.play, onPressed: ctl.start)],
      TimerState.running => [
          DLButton(label: t.tPause, icon: DLIcons.pause, variant: DLButtonVariant.secondary, onPressed: ctl.pause),
          DLButton(label: t.tStop, icon: DLIcons.stop, variant: DLButtonVariant.danger, onPressed: stop),
        ],
      TimerState.paused => [
          DLButton(label: t.tResume, icon: DLIcons.play, onPressed: ctl.resume),
          DLButton(label: t.tStop, icon: DLIcons.stop, variant: DLButtonVariant.danger, onPressed: stop),
        ],
      TimerState.stopped => [
          DLButton(label: t.tStart, icon: DLIcons.play, variant: DLButtonVariant.secondary, onPressed: ctl.start),
          DLButton(label: t.markDone, icon: DLIcons.check, onPressed: canComplete ? complete : null),
        ],
    };

    return Scaffold(
      appBar: appBar,
      body: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s6 + MediaQuery.paddingOf(context).bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t.selectTask, style: DLText.textLabel.copyWith(color: c.textPrimary)),
                  const SizedBox(height: DLSpace.s1),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final (i, k) in choices.indexed) ...[
                          if (i > 0) const SizedBox(width: DLSpace.s2),
                          // Locked while the timer runs or is paused.
                          Opacity(
                            opacity: busy && k.id != taskId ? 0.4 : 1,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 240),
                              child: DLChip(label: k.title, selected: k.id == taskId, onTap: busy ? null : () => ctl.pickTask(k.id)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: DLSpace.s6),
                  Center(
                    child: Ticking(
                      active: state == TimerState.running,
                      builder: (context) {
                        final seconds = timer.elapsedMs(now()) ~/ 1000;
                        return DLProgressRing(
                          size: 240,
                          radius: 104,
                          value: (seconds % 3600) / 3600,
                          color: ringColor,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                f.stopwatch(seconds),
                                style: DLText.amountHero.copyWith(fontSize: 40, height: 48 / 40, color: c.textPrimary),
                              ),
                              const SizedBox(height: DLSpace.s1),
                              DLTag(label: stateLabel, tone: tagTone),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: DLSpace.s2),
                  Text(
                    task == null ? t.selectTask : '${task.title} · ${projectName(projects, task.projectId)}',
                    textAlign: TextAlign.center,
                    style: DLText.textBody.copyWith(color: c.textSecondary),
                  ),
                  const SizedBox(height: DLSpace.s1),
                  Text(t.timerHint, textAlign: TextAlign.center, style: DLText.textBodySm.copyWith(color: c.textSecondary)),
                  if (state == TimerState.stopped) ...[
                    const SizedBox(height: DLSpace.s4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: c.successSoft, borderRadius: BorderRadius.circular(DLRadius.md)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(DLIcons.checkCircle, size: 16, color: c.successText),
                          const SizedBox(width: DLSpace.s2),
                          Flexible(
                            child: Text(t.logged(f.duration(timer.lastLoggedMinutes)), style: DLText.textLabel.copyWith(color: c.successText)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  const SizedBox(height: DLSpace.s6),
                  Row(
                    children: [
                      for (final (i, b) in buttons.indexed) ...[
                        if (i > 0) const SizedBox(width: DLSpace.s2),
                        Expanded(child: b),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
