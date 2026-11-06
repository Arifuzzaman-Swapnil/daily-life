import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';
import '../../core/format/dl_format_more.dart';
import '../../core/format/format_provider.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import 'health_providers.dart';

/// A habit (prototype `habitDetail`, screenshot 62): current and best streak,
/// this month's completion, and the month's calendar. Past days and today can
/// be toggled; future days can't.
class HabitDetailScreen extends ConsumerWidget {
  const HabitDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final today = dateOnly(ref.watch(clockProvider)());
    final h = ref.watch(habitProvider(id));

    Future<void> delete(String habitId, String name) async {
      final ok = await showDLConfirm(context, title: t.delHabitQ, body: name);
      if (!ok || !context.mounted) return;
      await ref.read(healthDaoProvider).deleteHabit(habitId);
      if (!context.mounted) return;
      DLToast.show(context, t.habitDeleted);
      popOr(context, Routes.health);
    }

    final appBar = DLAppBar(
      title: h?.habit.name ?? t.habits,
      onLeading: () => popOr(context, Routes.health),
      actions: [
        if (h != null) DLIconButton(icon: DLIcons.trash, tooltip: t.del, onPressed: () => delete(h.habit.id, h.habit.name)),
      ],
    );
    if (h == null) return Scaffold(appBar: appBar, body: const SizedBox.shrink());

    final month = DateTime(today.year, today.month);
    final lead = (month.weekday % 7 + 1) % 7; // blank cells before the 1st (Saturday first)
    final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
    final week = weekStartOf(today);
    final weekDone = [for (var i = 0; i < 7; i++) DateTime(week.year, week.month, week.day + i)].where(h.isDoneOn).length;

    Widget stat(String value, String label, {Color? color}) => Expanded(
          child: DLCard(
            padding: const EdgeInsets.all(DLSpace.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: DLText.amountMd.copyWith(color: color ?? c.textPrimary)),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: DLText.textCaption.copyWith(color: c.textSecondary)),
              ],
            ),
          ),
        );

    Widget cell(int day) {
      final d = DateTime(today.year, today.month, day);
      final on = h.isDoneOn(d);
      final future = d.isAfter(today);
      final isToday = day == today.day;
      const shape = BorderRadius.all(Radius.circular(10));
      return DLPressable(
        onTap: future ? null : () => ref.read(healthDaoProvider).toggle(h.habit.id, d),
        toggled: future ? null : on,
        semanticLabel: f.dateLong(d),
        excludeSemantics: true,
        borderRadius: shape,
        decoration: BoxDecoration(
          color: on ? c.success : (future ? c.surface.withValues(alpha: 0) : c.surfaceSunken),
          borderRadius: shape,
          border: isToday ? Border.all(color: c.accent, width: 2) : null,
        ),
        child: SizedBox(
          height: 40,
          child: Center(
            child: Text(
              f.count(day),
              style: DLText.amountSm.copyWith(color: on ? c.onSuccess : (future ? c.textDisabled : c.textPrimary)),
            ),
          ),
        ),
      );
    }

    final cells = [for (var i = 0; i < lead; i++) null, for (var d = 1; d <= daysInMonth; d++) d];

    return Scaffold(
      appBar: appBar,
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                stat(f.count(currentStreak(h.dayKeys, today)), t.streak2, color: c.warningText),
                const SizedBox(width: DLSpace.s3),
                stat(f.count(bestStreak(h.dayKeys)), t.bestStreak),
                const SizedBox(width: DLSpace.s3),
                stat(f.percent(monthCompletion(h.dayKeys, today)), t.completion),
              ],
            ),
          ),
          const SizedBox(height: DLSpace.s3),
          DLCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(f.monthYear(month), style: DLText.textH3.copyWith(color: c.textPrimary))),
                    const SizedBox(width: DLSpace.s2),
                    Flexible(
                      child: Text(t.tapDay, textAlign: TextAlign.end, style: DLText.textCaption.copyWith(color: c.textSecondary)),
                    ),
                  ],
                ),
                const SizedBox(height: DLSpace.s2),
                Row(
                  children: [
                    for (final (i, w) in f.weekHeaders().indexed) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(child: Text(w, maxLines: 1, textAlign: TextAlign.center, style: DLText.textCaption.copyWith(color: c.textSecondary))),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                for (var r = 0; r * 7 < cells.length; r++) ...[
                  if (r > 0) const SizedBox(height: 6),
                  Row(
                    children: [
                      for (var i = 0; i < 7; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: r * 7 + i < cells.length && cells[r * 7 + i] != null ? cell(cells[r * 7 + i]!) : const SizedBox(height: 40),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: DLSpace.s3),
          DLList(
            children: [
              DLKeyValueRow(label: t.remindAt, value: h.habit.reminderTime == null ? t.none : f.time(h.habit.reminderTime!)),
              DLKeyValueRow(label: t.thisWeek, value: '${f.count(weekDone)}/${f.count(7)}'),
            ],
          ),
        ],
      ),
    );
  }
}
