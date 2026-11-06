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
import 'project_sheet.dart';
import 'work_providers.dart';
import 'work_ui.dart';

/// Projects (prototype `projects`, screenshot 37): each with its progress,
/// task counts and logged time.
class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final list = ref.watch(projectStatsProvider).value;
    void add() => showNewProjectSheet(context);

    return Scaffold(
      appBar: DLAppBar(
        title: t.projects,
        onLeading: () => popOr(context, Routes.work),
        actions: [DLIconButton(icon: DLIcons.plus, tooltip: t.newProject, onPressed: add)],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          if (list != null && list.isEmpty)
            DLEmptyState(inCard: true, icon: DLIcons.folder, title: t.noProjects, actionLabel: t.newProject, onAction: add),
          for (final (i, s) in (list ?? const []).indexed) ...[
            if (i > 0) const SizedBox(height: DLSpace.s3),
            DLCard(
              onTap: () => context.push(Routes.project(s.project.id)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      DLIconChip(icon: DLIcons.folder, tone: projectTones[i % projectTones.length]),
                      const SizedBox(width: DLSpace.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.project.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: DLText.textH3.copyWith(color: c.textPrimary)),
                            if (s.project.description.isNotEmpty)
                              Text(
                                s.project.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DLText.textBodySm.copyWith(color: c.textSecondary),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DLSpace.s2),
                  DLProgressBar(value: s.tasks == 0 ? 0 : s.done / s.tasks, tone: DLTone.success),
                  const SizedBox(height: DLSpace.s2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${t.tasksN(f.count(s.tasks))} · ${t.tasksDoneN(f.count(s.done))}',
                          style: DLText.textBodySm.copyWith(color: c.textSecondary),
                        ),
                      ),
                      const SizedBox(width: DLSpace.s2),
                      Text(f.duration(s.minutes), style: DLText.amountSm.copyWith(color: c.textPrimary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A project (prototype `projectDetail`, screenshot 38): totals on the hero and
/// its tasks, newest first; "Add" starts a task in it.
class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final project = (ref.watch(projectsProvider).value ?? const <Project>[]).where((p) => p.id == id).firstOrNull;
    final tasks = ref.watch(projectTasksProvider(id)).value ?? const <Task>[];
    final appBar = DLAppBar(title: project?.name ?? t.project, onLeading: () => popOr(context, Routes.projects));
    if (project == null) return Scaffold(appBar: appBar, body: const SizedBox.shrink());

    final done = tasks.where((k) => k.status == TaskStatus.done).length;
    final minutes = tasks.fold<int>(0, (sum, k) => sum + k.spentMinutes);
    void add() => context.push(Routes.newTask(projectId: id));

    Widget tile(String value, String label) => Expanded(
          child: DLHeroTile(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(value, maxLines: 1, style: DLText.amountMd.copyWith(color: c.onBrand)),
                ),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: DLText.textCaption.copyWith(color: c.brandMuted)),
              ],
            ),
          ),
        );

    return Scaffold(
      appBar: appBar,
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          DLHero(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  project.description.isEmpty ? t.project : project.description,
                  style: DLText.textBodySm.copyWith(color: c.brandMuted),
                ),
                const SizedBox(height: DLSpace.s3),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      tile(f.duration(minutes), t.totalH),
                      const SizedBox(width: DLSpace.s3),
                      tile('${f.count(done)}/${f.count(tasks.length)}', t.completed),
                      const SizedBox(width: DLSpace.s3),
                      tile(f.percent(tasks.isEmpty ? 0 : done / tasks.length * 100), t.progressL),
                    ],
                  ),
                ),
              ],
            ),
          ),
          DLSectionTitle(t.tasksN2, trailing: DLLinkButton(label: t.add, onPressed: add, chevron: false)),
          if (tasks.isEmpty)
            DLEmptyState(inCard: true, icon: DLIcons.briefcase, title: t.noWork, actionLabel: t.addWork, onAction: add)
          else
            DLList(
              children: [
                for (final k in tasks)
                  DLListRow(
                    leading: _DoneMark(done: k.status == TaskStatus.done),
                    title: k.title,
                    subtitle: '${f.dateMedium(k.date)} · ${f.duration(k.spentMinutes)}',
                    trailing: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.3),
                      child: DLTag(label: statusLabel(t, k.status), tone: statusTone(k.status)),
                    ),
                    onTap: () => context.push(Routes.task(k.id)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The read-only checkbox look on a project's task rows (prototype `.chk`).
class _DoneMark extends StatelessWidget {
  const _DoneMark({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: done ? c.success : null,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: done ? c.success : c.borderStrong, width: 2),
      ),
      child: done ? Icon(DLIcons.check, size: 16, color: c.onSuccess) : null,
    );
  }
}
