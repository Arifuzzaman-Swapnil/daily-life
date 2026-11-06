import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import '../../core/db/daos/goals_dao.dart';
import '../../core/db/db_providers.dart';
import '../../core/format/dl_format.dart';
import '../../core/format/dl_format_more.dart';
import '../../core/format/format_provider.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import 'goals_providers.dart';

String goalCategoryLabel(AppLocalizations t, GoalCategory c) => switch (c) {
      GoalCategory.financial => t.gc_financial,
      GoalCategory.career => t.gc_career,
      GoalCategory.learning => t.gc_learning,
      GoalCategory.health => t.gc_health,
      GoalCategory.personal => t.gc_personal,
    };

DLTone goalTone(GoalCategory c) => switch (c) {
      GoalCategory.financial => DLTone.success,
      GoalCategory.career => DLTone.accent,
      GoalCategory.learning => DLTone.teal,
      GoalCategory.health => DLTone.danger,
      GoalCategory.personal => DLTone.warning,
    };

/// "Achieved", "N days left" or "Overdue".
String goalLeft(AppLocalizations t, DLFormat f, Goal g, DateTime today) {
  if (g.achieved) return t.achieved;
  final days = DateTime.utc(g.targetDate.year, g.targetDate.month, g.targetDate.day).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  return days >= 0 ? t.daysLeft(f.count(days)) : t.overdue;
}

/// "2/4 Milestones".
String milestoneCount(AppLocalizations t, DLFormat f, GoalWithMilestones g) => '${f.count(g.doneCount)}/${f.count(g.milestones.length)} ${t.milestones}';

/// Personal goals (prototype `goals`, screenshot 63): Active / Achieved with
/// counts, categories, and each goal's progress.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final today = dateOnly(ref.watch(clockProvider)());
    final filter = ref.watch(goalFilterProvider);
    final ctl = ref.read(goalFilterProvider.notifier);
    final all = ref.watch(goalsProvider).value;
    final goals = all ?? const <GoalWithMilestones>[];
    final list = [
      for (final g in goals)
        if (g.goal.achieved == filter.achieved && (filter.category == null || g.goal.category == filter.category)) g,
    ];
    final active = goals.where((g) => !g.goal.achieved).length;
    void add() => context.push(Routes.newGoal);

    return Scaffold(
      appBar: DLAppBar(
        title: t.goalsT,
        onLeading: () => popOr(context, Routes.more),
        actions: [DLIconButton(icon: DLIcons.plus, tooltip: t.newGoal, onPressed: add)],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          DLSegmentedTabs<bool>(
            value: filter.achieved,
            options: [
              (false, '${t.active} (${f.count(active)})'),
              (true, '${t.achieved} (${f.count(goals.length - active)})'),
            ],
            onChanged: ctl.setAchieved,
          ),
          const SizedBox(height: DLSpace.s2),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (i, (cat, label)) in [(null, t.all), for (final x in GoalCategory.values) (x, goalCategoryLabel(t, x))].indexed) ...[
                  if (i > 0) const SizedBox(width: DLSpace.s2),
                  DLChip(label: label, selected: filter.category == cat, onTap: () => ctl.setCategory(cat)),
                ],
              ],
            ),
          ),
          const SizedBox(height: DLSpace.s2),
          if (all != null && list.isEmpty)
            DLEmptyState(inCard: true, icon: DLIcons.target, title: t.noGoals, body: t.noGoalsSub, actionLabel: t.newGoal, onAction: add),
          for (final (i, g) in list.indexed) ...[
            if (i > 0) const SizedBox(height: DLSpace.s3),
            DLCard(
              onTap: () => context.push(Routes.goal(g.goal.id)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(child: DLTag(label: goalCategoryLabel(t, g.goal.category), tone: goalTone(g.goal.category))),
                      const SizedBox(width: DLSpace.s2),
                      Text(goalLeft(t, f, g.goal, today), style: DLText.textBodySm.copyWith(color: c.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: DLSpace.s2),
                  Text(g.goal.title, style: DLText.textH3.copyWith(color: c.textPrimary)),
                  const SizedBox(height: DLSpace.s2),
                  Row(
                    children: [
                      Expanded(child: DLProgressBar(value: g.percent / 100, tone: g.goal.achieved ? DLTone.success : DLTone.accent)),
                      const SizedBox(width: DLSpace.s2),
                      Text(f.percent(g.percent), style: DLText.amountSm.copyWith(color: c.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: DLSpace.s2),
                  Row(
                    children: [
                      Icon(DLIcons.flag, size: 16, color: c.textSecondary),
                      const SizedBox(width: DLSpace.s1),
                      Expanded(child: Text(milestoneCount(t, f, g), style: DLText.textBodySm.copyWith(color: c.textSecondary))),
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

/// A goal (prototype `goalDetail`, screenshot 64): progress on the hero,
/// milestones to tick or add, edit, mark achieved / reopen, delete.
class GoalDetailScreen extends ConsumerStatefulWidget {
  const GoalDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends ConsumerState<GoalDetailScreen> {
  final _milestone = TextEditingController();

  @override
  void dispose() {
    _milestone.dispose();
    super.dispose();
  }

  Future<void> _addMilestone(String goalId) async {
    final text = _milestone.text.trim();
    if (text.isEmpty) return;
    await ref.read(goalsDaoProvider).addMilestone(goalId, text);
    _milestone.clear();
  }

  Future<void> _delete(Goal g) async {
    final t = AppLocalizations.of(context);
    final ok = await showDLConfirm(context, title: '${t.del}?', body: g.title);
    if (!ok || !mounted) return;
    await ref.read(goalsDaoProvider).deleteGoal(g.id);
    if (mounted) popOr(context, Routes.goals);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final today = dateOnly(ref.watch(clockProvider)());
    final g = ref.watch(goalProvider(widget.id)).value;
    final appBar = DLAppBar(
      title: t.goalDetail,
      onLeading: () => popOr(context, Routes.goals),
      actions: [if (g != null) DLIconButton(icon: DLIcons.trash, tooltip: t.del, onPressed: () => _delete(g.goal))],
    );
    if (g == null) return Scaffold(appBar: appBar, body: const SizedBox.shrink());
    final goal = g.goal;
    final dao = ref.read(goalsDaoProvider);

    return Scaffold(
      appBar: appBar,
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          DLHero(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: DLTag(label: goalCategoryLabel(t, goal.category), background: c.brandHover, foreground: c.onBrandAccent),
                    ),
                    const SizedBox(width: DLSpace.s2),
                    Text(goalLeft(t, f, goal, today), style: DLText.textBodySm.copyWith(color: c.brandMuted)),
                  ],
                ),
                const SizedBox(height: DLSpace.s2),
                Text(goal.title, style: DLText.textH2.copyWith(color: c.onBrand)),
                if (goal.description.isNotEmpty) Text(goal.description, style: DLText.textBodySm.copyWith(color: c.brandMuted)),
                const SizedBox(height: DLSpace.s4),
                Row(
                  children: [
                    Expanded(child: DLProgressBar(value: g.percent / 100, color: c.accent, trackColor: c.brandHover)),
                    const SizedBox(width: DLSpace.s2),
                    Text(f.percent(g.percent), style: DLText.amountMd.copyWith(color: c.onBrand)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${t.targetDate}: ${f.dateMedium(goal.targetDate)} · ${goal.achieved ? t.achieved : t.active}',
                  style: DLText.textCaption.copyWith(color: c.brandMuted),
                ),
              ],
            ),
          ),
          if (goal.achieved) ...[
            const SizedBox(height: DLSpace.s3),
            DLNote(t.goalAchieved, tone: DLTone.success, icon: DLIcons.checkCircle),
          ],
          DLSectionTitle(t.milestones, trailing: Text(milestoneCount(t, f, g), style: DLText.amountSm.copyWith(color: c.textSecondary))),
          DLList(
            children: [
              // A milestone row toggles as a whole (prototype `role=checkbox`).
              for (final m in g.milestones)
                DLPressable(
                  onTap: () async {
                    await dao.setMilestoneDone(m.id, !m.done);
                    if (context.mounted) DLToast.show(context, t.progressSaved);
                  },
                  toggled: m.done,
                  pressedColor: c.surfaceSunken,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(DLSpace.s2, DLSpace.s1, DLSpace.s4, DLSpace.s1),
                      child: Row(
                        children: [
                          ExcludeSemantics(child: IgnorePointer(child: DLCheckbox(value: m.done, onChanged: (_) {}))),
                          const SizedBox(width: DLSpace.s1),
                          Expanded(child: Text(m.title, style: DLText.textBody.copyWith(color: m.done ? c.textSecondary : c.textPrimary))),
                        ],
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s3, DLSpace.s1),
                child: Row(
                  children: [
                    Icon(DLIcons.plus, size: 20, color: c.textSecondary),
                    const SizedBox(width: DLSpace.s3),
                    Expanded(
                      child: TextField(
                        controller: _milestone,
                        style: DLText.textBody.copyWith(color: c.textPrimary),
                        cursorColor: c.accent,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addMilestone(goal.id),
                        decoration: InputDecoration(
                          hintText: t.phMilestone,
                          hintStyle: DLText.textBody.copyWith(color: c.textSecondary),
                          isDense: true,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: DLSpace.s2),
                    DLButton(label: t.add, size: DLButtonSize.sm, variant: DLButtonVariant.tonal, onPressed: () => _addMilestone(goal.id)),
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
                  label: t.edit,
                  icon: DLIcons.edit,
                  variant: DLButtonVariant.secondary,
                  onPressed: () => context.push(Routes.editGoal(goal.id)),
                ),
              ),
              const SizedBox(width: DLSpace.s2),
              Expanded(
                child: DLButton(
                  label: goal.achieved ? t.reopen : t.markAchieved,
                  icon: goal.achieved ? DLIcons.undo : DLIcons.checkCircle,
                  onPressed: () async {
                    await dao.setAchieved(goal.id, !goal.achieved);
                    if (!goal.achieved && context.mounted) DLToast.show(context, t.goalAchieved);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
