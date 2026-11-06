import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import '../../core/db/daos/health_dao.dart';
import '../../core/db/db_providers.dart';
import '../../core/format/dl_format.dart';
import '../../core/format/dl_format_more.dart';
import '../../core/format/format_provider.dart';
import '../../core/prefs/health_prefs.dart';
import '../../core/prefs/notification_prefs.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../notifications/notification_planner.dart';
import 'health_providers.dart';

/// A meal's icon and tone (prototype `mealIcon`).
(IconData, DLTone) mealIcon(MealType m) => switch (m) {
      MealType.breakfast => (DLIcons.coffee, DLTone.warning),
      MealType.lunch => (DLIcons.food, DLTone.accent),
      MealType.snack => (DLIcons.coffee, DLTone.teal),
      MealType.dinner => (DLIcons.moon, DLTone.neutral),
    };

/// Health & habits (prototype `health`, screenshots 58, 59, 61): water, food
/// and habits.
class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key, this.tab = HealthTab.water});

  /// The tab it opens on (Home's water / meals / habits tiles).
  final HealthTab tab;

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  late HealthTab _tab = widget.tab;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tab = _tab;
    return Scaffold(
      appBar: DLAppBar(title: t.health, onLeading: () => popOr(context, Routes.more)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          DLSegmentedTabs<HealthTab>(
            value: tab,
            options: [(HealthTab.water, t.water), (HealthTab.food, t.food), (HealthTab.habits, t.habits)],
            onChanged: (v) => setState(() => _tab = v),
          ),
          switch (tab) {
            HealthTab.water => const _WaterTab(),
            HealthTab.food => const _FoodTab(),
            HealthTab.habits => const _HabitsTab(),
          },
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- water

/// Adds [ml] now and says so.
Future<void> addWater(BuildContext context, WidgetRef ref, int ml) async {
  final t = AppLocalizations.of(context);
  final f = ref.read(formatProvider);
  final now = ref.read(clockProvider)();
  String two(int n) => n.toString().padLeft(2, '0');
  await ref.read(healthDaoProvider).addWater(date: dateOnly(now), time: '${two(now.hour)}:${two(now.minute)}', ml: ml);
  if (context.mounted) DLToast.show(context, t.waterAdded(f.group(ml)));
}

class _WaterTab extends ConsumerWidget {
  const _WaterTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final log = ref.watch(todayWaterLogProvider).value;
    final ml = (log ?? const <WaterEntry>[]).fold<int>(0, (a, w) => a + w.ml);
    final target = ref.watch(waterTargetProvider);
    final reminders = ref.watch(notificationPrefsProvider)[NotifKind.water];
    final p = ml / target;
    String mlText(num n) => t.ml(f.group(n));

    Widget figure(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(value, textAlign: TextAlign.center, style: DLText.amountSm.copyWith(color: c.textPrimary)),
              Text(label, textAlign: TextAlign.center, style: DLText.textCaption.copyWith(color: c.textSecondary)),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: DLSpace.s3),
        DLCard(
          padding: const EdgeInsets.symmetric(horizontal: DLSpace.s4, vertical: DLSpace.s5),
          child: Column(
            children: [
              DLProgressRing(
                value: p,
                radius: 80,
                semanticLabel: '${t.consumed} ${mlText(ml)}',
                semanticValue: f.percent(p * 100),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(DLIcons.drop, color: c.accentText),
                    Text(mlText(ml), style: DLText.amountLg.copyWith(color: c.textPrimary)),
                    Text(f.percent(p * 100), style: DLText.textBodySm.copyWith(color: c.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: DLSpace.s4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  figure(mlText(target), t.dailyTarget),
                  figure(mlText(ml), t.consumed),
                  figure(mlText(ml >= target ? 0 : target - ml), t.remainingW),
                ],
              ),
              if (p >= 1) ...[
                const SizedBox(height: DLSpace.s3),
                DLNote(t.goalMet, tone: DLTone.success, icon: DLIcons.checkCircle),
              ],
            ],
          ),
        ),
        const SizedBox(height: DLSpace.s3),
        Row(
          children: [
            for (final (i, (label, icon, onTap)) in [
              for (final v in [150, 250, 500]) (t.ml(f.count(v)), DLIcons.drop, () => addWater(context, ref, v)),
              (t.customAmt, DLIcons.plus, () => _showWaterSheet(context, target: false)),
            ].indexed) ...[
              if (i > 0) const SizedBox(width: DLSpace.s2),
              Expanded(
                child: DLCard(
                  onTap: onTap,
                  padding: const EdgeInsets.symmetric(horizontal: DLSpace.s1, vertical: DLSpace.s3),
                  child: Column(
                    children: [
                      Icon(icon, color: c.accentText),
                      const SizedBox(height: DLSpace.s1),
                      Text(label, maxLines: 1, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: DLText.amountSm.copyWith(color: c.textPrimary)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: DLSpace.s3),
        DLList(
          children: [
            DLListRow(
              leading: const DLIconChip(icon: DLIcons.target, tone: DLTone.accent),
              title: t.dailyTarget,
              subtitle: mlText(target),
              trailing: Text(t.change, style: DLText.textLabel.copyWith(color: c.accentText)),
              onTap: () => _showWaterSheet(context, target: true),
            ),
            DLListRow(
              leading: const DLIconChip(icon: DLIcons.bell, tone: DLTone.warning),
              title: t.waterRem,
              subtitle: t.every2h,
              trailing: DLSwitch(
                value: reminders,
                semanticLabel: t.waterRem,
                onChanged: (v) => ref.read(notificationPrefsProvider.notifier).set(NotifKind.water, v),
              ),
            ),
          ],
        ),
        DLSectionTitle(t.intakeHistory),
        if (log != null && log.isEmpty) DLEmptyState(inCard: true, icon: DLIcons.drop, title: t.noWater),
        if (log != null && log.isNotEmpty)
          DLList(
            children: [
              for (final w in log)
                DLListRow(
                  minHeight: 56,
                  leading: const DLIconChip(icon: DLIcons.drop, tone: DLTone.accent, size: 36),
                  title: f.time(w.time),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(mlText(w.ml), style: DLText.amountMd.copyWith(color: c.textPrimary)),
                      DLIconButton(
                        icon: DLIcons.close,
                        iconSize: 20,
                        tooltip: t.removeEntry,
                        onPressed: () => ref.read(healthDaoProvider).deleteWater(w.id),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Custom amount (50–2000 ml) or the daily target (500–6000 ml).
Future<void> _showWaterSheet(BuildContext context, {required bool target}) {
  final t = AppLocalizations.of(context);
  return showDLSheet<void>(context, title: target ? t.setTarget : t.customAmt, builder: (_) => _WaterSheet(target: target));
}

class _WaterSheet extends ConsumerStatefulWidget {
  const _WaterSheet({required this.target});

  final bool target;

  @override
  ConsumerState<_WaterSheet> createState() => _WaterSheetState();
}

class _WaterSheetState extends ConsumerState<_WaterSheet> {
  late final _ml = TextEditingController(text: widget.target ? '${ref.read(waterTargetProvider)}' : '');
  String? _error;

  @override
  void dispose() {
    _ml.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final ml = DLFormat.parseAmount(_ml.text)?.round();
    final (min, max) = widget.target ? (WaterTarget.minMl, WaterTarget.maxMl) : (50, 2000);
    if (ml == null || ml < min || ml > max) {
      setState(() => _error = t.errMl);
      return;
    }
    if (widget.target) {
      await ref.read(waterTargetProvider.notifier).set(ml);
      if (!mounted) return;
      DLToast.show(context, t.targetSaved);
      Navigator.of(context).pop();
    } else {
      await addWater(context, ref, ml);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DLTextField(
          controller: _ml,
          label: t.amountMl,
          amount: true,
          autofocus: true,
          keyboardType: TextInputType.number,
          error: _error,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        Row(
          children: [
            Expanded(child: DLButton(label: t.cancel, variant: DLButtonVariant.secondary, onPressed: () => Navigator.of(context).pop())),
            const SizedBox(width: DLSpace.s2),
            Expanded(child: DLButton(label: t.save, onPressed: _save)),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- food

class _FoodTab extends ConsumerWidget {
  const _FoodTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final today = dateOnly(ref.watch(clockProvider)());
    final meals = ref.watch(todayMealsProvider).value ?? const <Meal>[];
    final history = ref.watch(mealHistoryProvider).value ?? const <Meal>[];
    final reminders = ref.watch(notificationPrefsProvider)[NotifKind.meal];

    // History by day, newest first (the query sorts).
    final days = <(DateTime, List<Meal>)>[];
    for (final m in history) {
      if (days.isEmpty || dayKey(days.last.$1) != dayKey(m.date)) days.add((m.date, []));
      days.last.$2.add(m);
    }
    void addMeal() {
      final had = meals.map((m) => m.type).toSet();
      final next = MealType.values.where((m) => !had.contains(m)).firstOrNull ?? MealType.snack;
      context.push(Routes.newMeal(next));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: DLSpace.s4, bottom: DLSpace.s3),
          child: Row(
            children: [
              Expanded(child: Semantics(header: true, child: Text(t.today, style: DLText.textH3.copyWith(color: c.textPrimary)))),
              Text('${t.mealsN(f.count(meals.length))} / ${f.count(4)}', style: DLText.textBodySm.copyWith(color: c.textSecondary)),
            ],
          ),
        ),
        _MealTimeline(
          children: [
            for (final type in MealType.values)
              Builder(builder: (context) {
                final m = meals.where((x) => x.type == type).firstOrNull;
                final (icon, tone) = mealIcon(type);
                return _MealSlot(
                  logged: m != null,
                  icon: icon,
                  tone: tone,
                  label: mealLabel(t, type),
                  time: f.time(m?.time ?? mealTimes[type]!),
                  desc: m?.description ?? t.notLogged,
                  actionIcon: m != null ? DLIcons.edit : DLIcons.plus,
                  actionLabel: m != null ? t.editMeal : t.addMeal,
                  onAction: () => context.push(m != null ? Routes.editMeal(m.id) : Routes.newMeal(type)),
                );
              }),
          ],
        ),
        const SizedBox(height: DLSpace.s3),
        DLList(
          children: [
            DLListRow(
              leading: const DLIconChip(icon: DLIcons.bell, tone: DLTone.warning),
              title: t.mealRem,
              trailing: DLSwitch(
                value: reminders,
                semanticLabel: t.mealRem,
                onChanged: (v) => ref.read(notificationPrefsProvider.notifier).set(NotifKind.meal, v),
              ),
            ),
          ],
        ),
        DLSectionTitle(t.mealHistory),
        for (final (day, items) in days) ...[
          DLSectionHeader('${f.relative(day, today)} · ${f.dateLong(day)}', first: true),
          DLList(
            children: [
              for (final m in items)
                Builder(builder: (context) {
                  final (icon, tone) = mealIcon(m.type);
                  return DLListRow(
                    leading: DLIconChip(icon: icon, tone: tone, size: 36),
                    title: mealLabel(t, m.type),
                    subtitle: m.description,
                    trailing: Text(f.time(m.time), style: DLText.textCaption.copyWith(color: c.textSecondary)),
                    onTap: () => context.push(Routes.editMeal(m.id)),
                  );
                }),
            ],
          ),
        ],
        const SizedBox(height: DLSpace.s4),
        DLButton(label: t.addMeal, icon: DLIcons.plus, onPressed: addMeal),
      ],
    );
  }
}

/// Today's four meals on a timeline (prototype `.tl`).
class _MealTimeline extends StatelessWidget {
  const _MealTimeline({required this.children});

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

class _MealSlot extends StatelessWidget {
  const _MealSlot({
    required this.logged,
    required this.icon,
    required this.tone,
    required this.label,
    required this.time,
    required this.desc,
    required this.actionIcon,
    required this.actionLabel,
    required this.onAction,
  });

  final bool logged;
  final IconData icon;
  final DLTone tone;
  final String label;
  final String time;
  final String desc;
  final IconData actionIcon;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    return DLCard(
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, DLSpace.s2, DLSpace.s1, DLSpace.s2),
            child: Row(
              children: [
                DLIconChip(icon: icon, tone: tone, size: 36),
                const SizedBox(width: DLSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          text: label,
                          children: [TextSpan(text: ' · $time', style: TextStyle(fontWeight: FontWeight.w400, color: c.textSecondary))],
                        ),
                        style: DLText.textLabel.copyWith(color: c.textPrimary),
                      ),
                      Text(
                        desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: DLText.textBodySm.copyWith(color: logged ? c.textPrimary : c.textSecondary),
                      ),
                    ],
                  ),
                ),
                DLIconButton(icon: actionIcon, iconSize: 20, tooltip: actionLabel, onPressed: onAction),
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
                color: logged ? c.success : c.borderStrong,
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

// ---------------------------------------------------------------- habits

/// Short weekday letters for the habit week strip, Saturday first
/// (prototype: Su Mo … / র সো …).
List<String> habitWeekLetters(AppLang lang) => lang == AppLang.en
    ? const ['Sa', 'Su', 'Mo', 'Tu', 'We', 'Th', 'Fr']
    : const ['শ', 'র', 'সো', 'ম', 'বু', 'বৃ', 'শু'];

class _HabitsTab extends ConsumerWidget {
  const _HabitsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final today = dateOnly(ref.watch(clockProvider)());
    final habits = ref.watch(habitsProvider).value;
    final list = habits ?? const <HabitWithChecks>[];
    final done = list.where((h) => h.isDoneOn(today)).length;
    final share = list.isEmpty ? 0.0 : done / list.length;
    final week = weekStartOf(today);
    final letters = habitWeekLetters(f.lang);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: DLSpace.s3),
        DLCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(t.todayDone(f.count(done), f.count(list.length)), style: DLText.textLabel.copyWith(color: c.textPrimary))),
                  Text(f.percent(share * 100), style: DLText.amountSm.copyWith(color: c.textPrimary)),
                ],
              ),
              const SizedBox(height: DLSpace.s2),
              DLProgressBar(value: share, tone: DLTone.teal),
            ],
          ),
        ),
        const SizedBox(height: DLSpace.s3),
        if (habits != null && habits.isEmpty)
          DLEmptyState(inCard: true, icon: DLIcons.flame, title: t.noHabits, body: t.noHabitsSub),
        for (final h in list) ...[
          DLCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    DLIconChip(icon: DLIcons.byKey(h.habit.icon), tone: DLTone.teal),
                    const SizedBox(width: DLSpace.s3),
                    Expanded(
                      child: DLPressable(
                        onTap: () => context.push(Routes.habit(h.habit.id)),
                        scaleOnPress: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(h.habit.name, style: DLText.textBody.copyWith(fontWeight: FontWeight.w600, color: c.textPrimary)),
                            Row(
                              children: [
                                Icon(DLIcons.flame, size: 16, color: c.warningText),
                                const SizedBox(width: DLSpace.s1),
                                Flexible(
                                  child: Text(
                                    t.streak(f.count(currentStreak(h.dayKeys, today))),
                                    style: DLText.textBodySm.copyWith(color: c.warningText),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    DLCheckbox(
                      round: true,
                      value: h.isDoneOn(today),
                      semanticLabel: h.habit.name,
                      onChanged: (_) => ref.read(healthDaoProvider).toggle(h.habit.id, today),
                    ),
                  ],
                ),
                const SizedBox(height: DLSpace.s3),
                Semantics(
                  label: t.thisWeek,
                  child: Row(
                    children: [
                      for (var i = 0; i < 7; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: Builder(builder: (context) {
                            final on = h.isDoneOn(DateTime(week.year, week.month, week.day + i));
                            return Container(
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: on ? c.success : c.surfaceSunken, borderRadius: BorderRadius.circular(DLRadius.sm)),
                              child: Text(
                                letters[i],
                                maxLines: 1,
                                style: DLText.textCaption.copyWith(fontWeight: FontWeight.w600, color: on ? c.onSuccess : c.textSecondary),
                              ),
                            );
                          }),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DLSpace.s3),
        ],
        DLAddButton(label: t.addHabit, onPressed: () => showDLSheet<void>(context, title: t.addHabit, builder: (_) => const _HabitSheet())),
      ],
    );
  }
}

class _HabitSheet extends ConsumerStatefulWidget {
  const _HabitSheet();

  @override
  ConsumerState<_HabitSheet> createState() => _HabitSheetState();
}

class _HabitSheetState extends ConsumerState<_HabitSheet> {
  final _name = TextEditingController();
  String _time = '21:00';
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = t.errTitle);
      return;
    }
    await ref.read(healthDaoProvider).addHabit(name: name, reminderTime: _time);
    if (!mounted) return;
    DLToast.show(context, t.habitSaved);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final f = ref.watch(formatProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DLTextField(
          controller: _name,
          label: t.habitName,
          hint: t.phHabit,
          error: _error,
          autofocus: true,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        DLPickerField(
          label: t.remindAt,
          value: f.time(_time),
          icon: DLIcons.clock,
          onTap: () async {
            final hm = await pickTime(context, _time);
            if (hm != null && mounted) setState(() => _time = hm);
          },
        ),
        Row(
          children: [
            Expanded(child: DLButton(label: t.cancel, variant: DLButtonVariant.secondary, onPressed: () => Navigator.of(context).pop())),
            const SizedBox(width: DLSpace.s2),
            Expanded(child: DLButton(label: t.save, onPressed: _save)),
          ],
        ),
      ],
    );
  }
}
