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
import 'work_ui.dart';

/// Work history (prototype `workHist`, screenshot 36): daily / weekly / monthly,
/// search, a project filter, totals, and a timeline grouped by day.
class WorkHistoryScreen extends ConsumerStatefulWidget {
  const WorkHistoryScreen({super.key});

  @override
  ConsumerState<WorkHistoryScreen> createState() => _WorkHistoryScreenState();
}

class _WorkHistoryScreenState extends ConsumerState<WorkHistoryScreen> {
  late final _search = TextEditingController(text: ref.read(workHistoryFilterProvider).search);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final filter = ref.watch(workHistoryFilterProvider);
    final ctl = ref.read(workHistoryFilterProvider.notifier);
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final tasks = ref.watch(workHistoryProvider).value;

    // Day groups, newest first (the query already sorts).
    final groups = <(DateTime, List<Task>)>[];
    for (final k in tasks ?? const <Task>[]) {
      if (groups.isEmpty || groups.last.$1 != k.date) groups.add((k.date, []));
      groups.last.$2.add(k);
    }
    int minutes(Iterable<Task> ks) => ks.fold(0, (sum, k) => sum + k.spentMinutes);

    Widget total(String value, String label) => Expanded(
          child: DLCard(
            padding: const EdgeInsets.all(DLSpace.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(value, maxLines: 1, style: DLText.amountMd.copyWith(color: c.textPrimary)),
                ),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: DLText.textCaption.copyWith(color: c.textSecondary)),
              ],
            ),
          ),
        );

    return Scaffold(
      appBar: DLAppBar(
        title: t.workHistory,
        onLeading: () => popOr(context, Routes.work),
        actions: [DLIconButton(icon: DLIcons.chart, tooltip: t.productivity, onPressed: () => context.push(Routes.reports))],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          DLSegmentedTabs<WorkView>(
            value: filter.view,
            options: [(WorkView.daily, t.dailyV), (WorkView.weekly, t.weeklyV), (WorkView.monthly, t.monthlyV)],
            onChanged: ctl.setView,
          ),
          const SizedBox(height: DLSpace.s3),
          DLSearchBar(hint: t.searchTasks, controller: _search, onChanged: ctl.setSearch),
          const SizedBox(height: DLSpace.s2),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (i, (id, name)) in [(null, t.all), for (final p in projects) (p.id, p.name)].indexed) ...[
                  if (i > 0) const SizedBox(width: DLSpace.s2),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: DLChip(label: name, selected: filter.projectId == id, onTap: () => ctl.setProject(id)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: DLSpace.s2),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                total(f.duration(minutes(tasks ?? const [])), t.totalH),
                const SizedBox(width: DLSpace.s3),
                total(f.count((tasks ?? const []).where((k) => k.status == TaskStatus.done).length), t.completed),
                const SizedBox(width: DLSpace.s3),
                total(f.count(tasks?.length ?? 0), t.tasksN2),
              ],
            ),
          ),
          if (tasks != null && tasks.isEmpty) ...[
            const SizedBox(height: DLSpace.s4),
            DLEmptyState(
              inCard: true,
              icon: DLIcons.clock,
              title: t.noWork,
              actionLabel: t.addWork,
              onAction: () => context.push(Routes.newTask()),
            ),
          ],
          for (final (day, items) in groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(DLSpace.s1, DLSpace.s4, DLSpace.s1, DLSpace.s2),
              child: Row(
                children: [
                  Expanded(child: Semantics(header: true, child: Text(f.dateLong(day), style: _dayHeading(c)))),
                  Text(f.duration(minutes(items)), style: _dayHeading(c)),
                ],
              ),
            ),
            WorkTimeline(
              children: [
                for (final k in items)
                  TimelineTaskCard(task: k, projectName: projectName(projects, k.projectId), onOpen: () => context.push(Routes.task(k.id))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static TextStyle _dayHeading(DLColors c) => DLText.textBodySm.copyWith(fontWeight: FontWeight.w600, color: c.textSecondary);
}
