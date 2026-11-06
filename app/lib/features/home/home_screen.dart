import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import '../../core/format/dl_format_more.dart';
import '../../core/format/format_provider.dart';
import '../../core/prefs/app_settings.dart';
import '../../core/prefs/dashboard_layout.dart';
import '../../core/prefs/health_prefs.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../calendar/calendar_providers.dart';
import '../finance/finance_screen.dart';
import '../finance/money_providers.dart';
import '../finance/month_sheet.dart';
import '../reminders/reminders_providers.dart';
import 'customize_sheet.dart';
import 'home_providers.dart';

/// Home tab (prototype `home`, screenshot 05; empty state 90): the date bar with
/// theme, notifications and settings, a greeting, the dashboard sections in the
/// person's order (customize sheet 07), and the customize button.
///
/// Work, calendar, reminder, health and notes screens arrive in build step 6;
/// until then their tiles and quick actions open the tab they will live under.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final showBangla = ref.watch(settingsProvider.select((s) => s.banglaDate));
    final now = ref.watch(clockProvider)();
    final sections = ref.watch(dashboardLayoutProvider).visible;
    final unread = (ref.watch(unreadCountProvider).value ?? 0) > 0;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Column(
      children: [
        DLAppBar.root(
          title: t.home,
          titleWidget: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(f.dateLong(now), maxLines: 1, overflow: TextOverflow.ellipsis, style: DLText.textLabel.copyWith(color: c.textSecondary)),
              if (showBangla)
                Text(f.bangla(now), maxLines: 1, overflow: TextOverflow.ellipsis, style: DLText.textCaption.copyWith(color: c.textSecondary)),
            ],
          ),
          actions: [
            DLIconButton(
              icon: dark ? DLIcons.sun : DLIcons.moon,
              tooltip: t.toggleTheme,
              onPressed: () => ref.read(settingsProvider.notifier).setThemeMode(dark ? ThemeMode.light : ThemeMode.dark),
            ),
            _BellButton(unread: unread),
            DLIconButton(icon: DLIcons.gear, tooltip: t.settings, onPressed: () => context.push(Routes.settings)),
          ],
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s8 + bottom),
            children: [
              const _Greeting(),
              const SizedBox(height: DLSpace.s5),
              for (final (i, s) in sections.indexed) _section(s, first: i == 0),
              const SizedBox(height: DLSpace.s6),
              DLButton(
                label: t.customize,
                icon: DLIcons.sliders,
                variant: DLButtonVariant.tonal,
                size: DLButtonSize.md,
                onPressed: () => showCustomizeSheet(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _section(DashSection s, {required bool first}) => switch (s) {
      DashSection.summary => _SummarySection(first: first),
      DashSection.chart => _ChartSection(first: first),
      DashSection.today => _TodaySection(first: first),
      DashSection.shop => _ShopSection(first: first),
      DashSection.quick => _QuickSection(first: first),
      DashSection.recent => _RecentSection(first: first),
    };

/// Opens the Finance tab on [tab] (prototype `goFinance` / `goIncome` / `goExpense`).
void _goFinance(BuildContext context, WidgetRef ref, FinTab tab) {
  ref.read(finFilterProvider.notifier).setTab(tab);
  context.go(Routes.finance);
}

/// The 24px gap above a section, dropped for the first one.
Widget _gap(bool first) => SizedBox(height: first ? 0 : DLSpace.s6);

class _BellButton extends StatelessWidget {
  const _BellButton({required this.unread});

  final bool unread;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    return Stack(
      children: [
        DLIconButton(icon: DLIcons.bell, tooltip: t.notifications, onPressed: () => context.push(Routes.notifications)),
        if (unread)
          Positioned(
            top: 12,
            right: 13,
            child: IgnorePointer(child: DLDot(color: c.danger, size: 10, ring: c.background)),
          ),
      ],
    );
  }
}

/// Avatar with the name's initial (opens Settings) and the time-of-day greeting.
class _Greeting extends ConsumerWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final name = ref.watch(settingsProvider.select((s) => s.displayName));
    final hour = ref.watch(clockProvider)().hour;
    final hello = hour >= 5 && hour < 12
        ? t.gm
        : hour >= 12 && hour < 16
            ? t.ga
            : hour >= 16 && hour < 21
                ? t.ge
                : t.gn;
    const avatar = 52.0;
    const shape = BorderRadius.all(Radius.circular(avatar / 2));
    return Row(
      children: [
        DLPressable(
          onTap: () => context.push(Routes.settings),
          semanticLabel: t.profile,
          excludeSemantics: true,
          borderRadius: shape,
          child: DLAvatar(name: name, size: avatar),
        ),
        const SizedBox(width: DLSpace.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(name.isEmpty ? '$hello!' : '$hello, $name!', style: DLText.textH1.copyWith(color: c.textPrimary)),
              ),
              Text(t.greetSub, style: DLText.textBody.copyWith(color: c.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Balance hero for the selected month, plus the savings card.
class _SummarySection extends ConsumerWidget {
  const _SummarySection({required this.first});

  final bool first;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final month = ref.watch(selectedMonthProvider);
    final totals = ref.watch(monthTotalsProvider(month)).value;
    final savings = ref.watch(savingsTotalProvider).value ?? 0;
    final monthLabel = f.monthYear(month);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _gap(first),
        DLBalanceHero(
          label: t.available,
          trailing: DLHeroPill(label: monthLabel, semanticLabel: '${t.monthSel}: $monthLabel', onTap: () => showMonthSheet(context)),
          amount: f.taka(totals?.available ?? 0),
          hint: t.availHint,
          onAmountTap: () => _goFinance(context, ref, FinTab.all),
          stats: [
            DLHeroStat(
              icon: DLIcons.income,
              label: t.totalIncome,
              amount: f.taka(totals?.income ?? 0),
              onTap: () => _goFinance(context, ref, FinTab.income),
            ),
            DLHeroStat(
              icon: DLIcons.expense,
              label: t.totalExpense,
              amount: f.taka(totals?.expense ?? 0),
              onTap: () => _goFinance(context, ref, FinTab.expense),
            ),
          ],
        ),
        const SizedBox(height: DLSpace.s3),
        DLCard(
          onTap: () => context.push(Routes.savings),
          child: _CardRow(
            icon: const DLIconChip(icon: DLIcons.piggy, tone: DLTone.success),
            body: [
              Text(t.totalSavings, style: DLText.textBodySm.copyWith(color: c.textSecondary)),
              Text(f.taka(savings), style: DLText.amountLg.copyWith(color: c.textPrimary)),
            ],
            trailing: DLTag(label: t.savMonthTag(f.taka(math.max(0, totals?.savingsNet ?? 0), sign: '+')), tone: DLTone.success),
          ),
        ),
      ],
    );
  }
}

/// A summary card's content (prototype `.card.btnc > .row`): icon chip, a
/// column of label and amount, and a trailing tag or link that never takes
/// more than 45 % of the row, so the amount keeps its room on small phones.
class _CardRow extends StatelessWidget {
  const _CardRow({required this.icon, required this.body, required this.trailing});

  final Widget icon;
  final List<Widget> body;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => Row(
        children: [
          icon,
          const SizedBox(width: DLSpace.s3),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: body)),
          const SizedBox(width: DLSpace.s2),
          ConstrainedBox(constraints: BoxConstraints(maxWidth: box.maxWidth * 0.45), child: trailing),
        ],
      ),
    );
  }
}

/// Income vs expenses over the last 6 or 12 months; a tapped bar's figures show
/// above the chart (the current month until one is tapped).
class _ChartSection extends ConsumerWidget {
  const _ChartSection({required this.first});

  final bool first;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final chart = ref.watch(homeChartProvider);
    final series = ref.watch(monthlySeriesProvider(chart.months)).value ?? const [];
    final picked = series.indexWhere((m) => m.month == chart.selected);
    final index = picked >= 0 ? picked : series.length - 1;
    final colors = [c.accent, c.chart2];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DLSectionTitle(
          t.incVsExp,
          first: first,
          trailing: DLSegmentedTabs<int>(
            value: chart.months,
            expand: false,
            options: [(6, t.m6), (12, t.m12)],
            onChanged: ref.read(homeChartProvider.notifier).setMonths,
          ),
        ),
        if (index >= 0)
          DLCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.monthYear(series[index].month), style: DLText.textLabel.copyWith(color: c.textPrimary)),
                          Text(
                            '${t.net} ${f.taka(series[index].income - series[index].expense)}',
                            style: DLText.textBodySm.copyWith(color: c.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: DLSpace.s2),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(f.taka(series[index].income, sign: '+'), style: DLText.amountSm.copyWith(color: c.successText)),
                        Text(f.taka(series[index].expense, sign: '-'), style: DLText.amountSm.copyWith(color: c.dangerText)),
                      ],
                    ),
                  ],
                ),
                DLBarChart(
                  colors: colors,
                  selectedIndex: index,
                  onSelect: (i) => ref.read(homeChartProvider.notifier).select(series[i].month),
                  semanticLabel: t.incVsExp,
                  groups: [
                    for (final (i, m) in series.indexed)
                      DLBarGroup(
                        // 12 months: every other label, as in the prototype.
                        label: series.length > 6 && i.isOdd ? '' : f.monthShort(m.month),
                        values: [m.income.toDouble(), m.expense.toDouble()],
                        semanticLabel: '${f.monthYear(m.month)}: ${t.income} ${f.taka(m.income)}, ${t.expense} ${f.taka(m.expense)}',
                      ),
                  ],
                ),
                const SizedBox(height: DLSpace.s3),
                Row(
                  children: [
                    DLChartLegend(items: [(colors[0], t.income), (colors[1], t.expense)]),
                    const SizedBox(width: DLSpace.s2),
                    Expanded(
                      child: Text(t.tapBar, textAlign: TextAlign.end, style: DLText.textCaption.copyWith(color: c.textSecondary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Today's tasks, meetings, events, reminders, water, meals and habits.
class _TodaySection extends ConsumerWidget {
  const _TodaySection({required this.first});

  final bool first;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final f = ref.watch(formatProvider);
    final today = dateOnly(ref.watch(clockProvider)());
    final tasks = ref.watch(todayTasksProvider).value ?? const <Task>[];
    final events = ref.watch(todayEventsProvider).value ?? const <Event>[];
    final reminders = ref.watch(todayRemindersProvider).value ?? const <Reminder>[];
    final water = ref.watch(todayWaterProvider).value ?? 0;
    final target = ref.watch(waterTargetProvider);
    final meals = ref.watch(todayMealsProvider).value ?? const <Meal>[];
    final habits = ref.watch(habitsProvider).value ?? const [];

    final done = tasks.where((x) => x.status == TaskStatus.done).length;
    final pending = [for (final x in tasks) if (x.status != TaskStatus.done) x];
    final meetings = [for (final e in events) if (e.category == EventCategory.meeting) e];
    final others = [for (final e in events) if (e.category != EventCategory.meeting) e];
    final habitsDone = habits.where((h) => h.isDoneOn(today)).length;
    String timed(String? time, String title) => time == null || time.isEmpty ? title : '${f.time(time)} · $title';
    String mealLabel(MealType m) => switch (m) {
          MealType.breakfast => t.breakfast,
          MealType.lunch => t.lunch,
          MealType.snack => t.snack,
          MealType.dinner => t.dinner,
        };
    void toWork() => context.go(Routes.work);
    // Meeting and event tiles open today's day view; "Agenda" the agenda.
    void toCalendar() {
      ref.read(calendarProvider.notifier).showToday(CalView.day);
      context.go(Routes.calendar);
    }

    void toAgenda() {
      ref.read(calendarProvider.notifier).setView(CalView.agenda);
      context.go(Routes.calendar);
    }
    void toMore() => context.go(Routes.more);

    final tiles = [
      _Tile(
        icon: DLIcons.checkCircle,
        tone: DLTone.success,
        value: '${f.count(done)}/${f.count(tasks.length)}',
        label: t.ovDone,
        sub: t.tasksN(f.count(tasks.length)),
        bar: tasks.isEmpty ? 0 : done / tasks.length,
        barTone: DLTone.success,
        onTap: toWork,
      ),
      _Tile(
        icon: DLIcons.briefcase,
        tone: DLTone.accent,
        value: f.count(pending.length),
        label: t.ovPending,
        sub: pending.isEmpty ? t.none : pending.first.title,
        onTap: toWork,
      ),
      _Tile(
        icon: DLIcons.users,
        tone: DLTone.teal,
        value: f.count(meetings.length),
        label: t.ovMeet,
        sub: meetings.isEmpty ? t.none : timed(meetings.first.startTime, meetings.first.title),
        onTap: toCalendar,
      ),
      _Tile(
        icon: DLIcons.calendar,
        tone: DLTone.accent,
        value: f.count(others.length),
        label: t.ovEvents,
        sub: others.isEmpty ? t.none : others.first.title,
        onTap: toCalendar,
      ),
      _Tile(
        icon: DLIcons.bell,
        tone: DLTone.warning,
        value: f.count(reminders.length),
        label: t.ovRem,
        sub: reminders.isEmpty ? t.none : timed(reminders.first.time, reminders.first.title),
        onTap: () {
          ref.read(remTabProvider.notifier).set(RemTab.today);
          context.push(Routes.reminders);
        },
      ),
      _Tile(
        icon: DLIcons.drop,
        tone: DLTone.accent,
        value: f.percent(water / target * 100),
        label: t.water,
        sub: '${t.ml(f.group(water))} / ${t.ml(f.group(target))}',
        bar: water / target,
        onTap: toMore,
      ),
      _Tile(
        icon: DLIcons.food,
        tone: DLTone.warning,
        value: '${f.count(meals.length)}/${f.count(4)}',
        label: t.meals,
        sub: meals.isEmpty ? t.notLogged : [for (final m in meals) mealLabel(m.type)].join(', '),
        onTap: toMore,
      ),
      _Tile(
        icon: DLIcons.flame,
        tone: DLTone.danger,
        value: '${f.count(habitsDone)}/${f.count(habits.length)}',
        label: t.habits,
        sub: t.todayDone(f.count(habitsDone), f.count(habits.length)),
        bar: habits.isEmpty ? 0 : habitsDone / habits.length,
        barTone: DLTone.teal,
        onTap: toMore,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DLSectionTitle(t.todayOverview, first: first, trailing: DLLinkButton(label: t.agenda, onPressed: toAgenda)),
        for (var r = 0; r < tiles.length; r += 2) ...[
          if (r > 0) const SizedBox(height: DLSpace.s3),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tiles[r]),
                const SizedBox(width: DLSpace.s3),
                Expanded(child: tiles[r + 1]),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// One "today" tile (prototype `.card.col.g8`): icon and figure, label, one
/// line of detail, and an optional 6px progress bar.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.tone,
    required this.value,
    required this.label,
    required this.sub,
    required this.onTap,
    this.bar,
    this.barTone = DLTone.accent,
  });

  final IconData icon;
  final DLTone tone;
  final String value;
  final String label;
  final String sub;
  final VoidCallback onTap;

  /// 0…1, or null for no bar.
  final double? bar;
  final DLTone barTone;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    return DLCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DLIconChip(icon: icon, tone: tone, size: 36),
              const SizedBox(width: DLSpace.s2),
              Expanded(
                child: Text(value, textAlign: TextAlign.end, maxLines: 1, style: DLText.amountMd.copyWith(color: c.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: DLSpace.s2),
          Text(label, style: DLText.textLabel.copyWith(color: c.textPrimary)),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: DLText.textBodySm.copyWith(color: c.textSecondary)),
          if (bar case final v?) ...[
            const SizedBox(height: DLSpace.s2),
            DLProgressBar(value: v, height: 6, tone: barTone),
          ],
        ],
      ),
    );
  }
}

/// Total owed across shops and how many shops have a balance.
class _ShopSection extends ConsumerWidget {
  const _ShopSection({required this.first});

  final bool first;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final due = ref.watch(shopDueProvider).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _gap(first),
        DLCard(
          onTap: () => context.push(Routes.shops),
          child: _CardRow(
            icon: const DLIconChip(icon: DLIcons.store, tone: DLTone.warning),
            body: [
              Text(t.outstanding, style: DLText.textBodySm.copyWith(color: c.textSecondary)),
              Text(f.taka(due?.total ?? 0), style: DLText.amountLg.copyWith(color: c.textPrimary)),
              Text(t.shopsDue(f.count(due?.shops ?? 0)), style: DLText.textBodySm.copyWith(color: c.textSecondary)),
            ],
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(t.openShop, style: DLText.textLabel.copyWith(color: c.accentText))),
                const SizedBox(width: DLSpace.s1),
                Icon(DLIcons.chevronRight, size: 16, color: c.accentText),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Five shortcuts: add income, add expense, add work, write a note, add a reminder.
class _QuickSection extends StatelessWidget {
  const _QuickSection({required this.first});

  final bool first;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final actions = [
      (DLIcons.income, DLTone.success, t.addIncome, () => context.push(Routes.newTx(TxType.income))),
      (DLIcons.expense, DLTone.danger, t.addExpense, () => context.push(Routes.newTx(TxType.expense))),
      (DLIcons.briefcase, DLTone.accent, t.addWork, () => context.push(Routes.newTask())),
      (DLIcons.edit, DLTone.teal, t.writeNote, () => context.push(Routes.newNote)),
      (DLIcons.bell, DLTone.warning, t.addReminder, () => context.push(Routes.newReminder(landOnList: true))),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DLSectionTitle(t.quick, first: first),
        DLCard(
          padding: const EdgeInsets.symmetric(horizontal: DLSpace.s2, vertical: DLSpace.s3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, (icon, tone, label, onTap)) in actions.indexed) ...[
                if (i > 0) const SizedBox(width: DLSpace.s2),
                Expanded(
                  child: DLPressable(
                    onTap: onTap,
                    semanticLabel: label,
                    excludeSemantics: true,
                    borderRadius: const BorderRadius.all(Radius.circular(DLRadius.md)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: DLSpace.s1),
                      child: Column(
                        children: [
                          DLIconChip(icon: icon, tone: tone, size: 52),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            style: DLText.textCaption.copyWith(fontWeight: FontWeight.w500, color: c.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The 5 newest transactions, or the "no transactions yet" state.
class _RecentSection extends ConsumerWidget {
  const _RecentSection({required this.first});

  final bool first;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final recent = ref.watch(recentTransactionsProvider).value;
    final book = ref.watch(categoryBookProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DLSectionTitle(t.recentTx, first: first, trailing: DLLinkButton(label: t.seeAll, onPressed: () => _goFinance(context, ref, FinTab.all))),
        if (recent != null && recent.isEmpty)
          DLEmptyState(
            inCard: true,
            icon: DLIcons.wallet,
            title: t.noTx,
            body: t.noTxSub,
            actionLabel: t.addIncome,
            onAction: () => context.push(Routes.newTx(TxType.income)),
          ),
        if (recent != null && recent.isNotEmpty && !book.isEmpty)
          DLList(children: [for (final x in recent) TxRow(x: x, book: book, relativeDate: true)]),
      ],
    );
  }
}
