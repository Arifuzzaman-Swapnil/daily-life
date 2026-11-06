import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import '../../core/files/file_service.dart';
import '../../core/format/dl_format.dart';
import '../../core/format/dl_format_more.dart';
import '../../core/format/format_provider.dart';
import '../../core/prefs/health_prefs.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../finance/categories.dart';
import '../finance/money_providers.dart';
import '../health/health_providers.dart';
import '../work/work_providers.dart';
import '../work/work_ui.dart';
import 'reports_providers.dart';

/// One KPI card's figures.
typedef _Kpi = ({String label, String value, String sub, Color? color});

/// Reports & analytics (prototype `reports`, screenshots 70–73): financial,
/// productivity and lifestyle, for a month (back 11 months) or a year (this
/// one and last), with a skeleton while the period's data loads and a CSV
/// export.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key, this.tab = ReportTab.fin});

  final ReportTab tab;

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late ReportTab _tab = widget.tab;
  bool _yearly = false;
  late final DateTime _thisMonth = currentMonth();
  late DateTime _month = _thisMonth;
  late int _year = _thisMonth.year;

  /// The tapped income/expense bar (1st of its month).
  DateTime? _selected;

  DateTime currentMonth() {
    final now = ref.read(clockProvider)();
    return DateTime(now.year, now.month);
  }

  ReportPeriod get _period => _yearly ? ReportPeriod.year(_year) : ReportPeriod.month(_month);

  DateTime get _earliestMonth => DateTime(_thisMonth.year, _thisMonth.month - 11);
  bool get _canPrev => _yearly ? _year > _thisMonth.year - 1 : _month.isAfter(_earliestMonth);
  bool get _canNext => _yearly ? _year < _thisMonth.year : _month.isBefore(_thisMonth);

  void _shift(int by) => setState(() {
        _selected = null;
        if (_yearly) {
          _year += by;
        } else {
          _month = DateTime(_month.year, _month.month + by);
        }
      });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final period = _period;

    final (bool loading, List<_Kpi> kpis, List<Widget> body, List<List<String>> csv) = switch (_tab) {
      ReportTab.fin => _finance(t, c, f, period),
      ReportTab.prod => _productivity(t, c, f, period),
      ReportTab.life => _lifestyle(t, c, f),
    };

    Future<void> export() async {
      final rows = [
        [t.reportsT, _yearly ? f.digitsOf(_year) : f.monthYear(_month)],
        for (final k in kpis) [k.label, k.value],
        ...csv,
      ];
      String cell(String s) => s.contains(RegExp('[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
      final content = rows.map((r) => r.map(cell).join(',')).join('\n');
      final name = 'daily-life-${_tab.name}-${_yearly ? _year : monthKey(_month)}.csv';
      await ref.read(fileServiceProvider).shareTextFile(name, content, subject: t.reportsT);
      if (context.mounted) DLToast.show(context, t.exportDone);
    }

    return Scaffold(
      appBar: DLAppBar(
        title: t.reportsT,
        onLeading: () => popOr(context, Routes.more),
        actions: [DLIconButton(icon: DLIcons.download, tooltip: t.exportD, onPressed: loading ? null : export)],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          DLSegmentedTabs<ReportTab>(
            value: _tab,
            options: [(ReportTab.fin, t.finR), (ReportTab.prod, t.prodR), (ReportTab.life, t.lifeR)],
            onChanged: (v) => setState(() => _tab = v),
          ),
          const SizedBox(height: DLSpace.s3),
          Row(
            children: [
              DLSegmentedTabs<bool>(
                expand: false,
                value: _yearly,
                options: [(false, t.month), (true, t.year)],
                onChanged: (v) => setState(() {
                  _yearly = v;
                  _selected = null;
                }),
              ),
              const SizedBox(width: DLSpace.s2),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    DLIconButton(icon: DLIcons.chevronLeft, size: 40, iconSize: 20, tooltip: t.prevMonth, onPressed: _canPrev ? () => _shift(-1) : null),
                    Flexible(
                      child: Text(
                        _yearly ? f.digitsOf(_year) : f.monthYear(_month),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: DLText.textLabel.copyWith(color: c.textPrimary),
                      ),
                    ),
                    DLIconButton(icon: DLIcons.chevronRight, size: 40, iconSize: 20, tooltip: t.nextMonth, onPressed: _canNext ? () => _shift(1) : null),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DLSpace.s4),
          if (loading) ...[
            Semantics(
              label: t.loading,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var r = 0; r < 2; r++) ...[
                    if (r > 0) const SizedBox(height: DLSpace.s3),
                    const Row(
                      children: [
                        Expanded(child: DLSkeleton(height: 84)),
                        SizedBox(width: DLSpace.s3),
                        Expanded(child: DLSkeleton(height: 84)),
                      ],
                    ),
                  ],
                  const SizedBox(height: DLSpace.s3),
                  const DLSkeleton(height: 200),
                  const SizedBox(height: DLSpace.s3),
                  const DLSkeleton(height: 160),
                  const SizedBox(height: DLSpace.s3),
                  Text(t.loading, textAlign: TextAlign.center, style: DLText.textBodySm.copyWith(color: c.textSecondary)),
                ],
              ),
            ),
          ] else ...[
            _KpiGrid(kpis: kpis),
            ...body,
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------- financial

  (bool, List<_Kpi>, List<Widget>, List<List<String>>) _finance(AppLocalizations t, DLColors c, DLFormat f, ReportPeriod period) {
    final series = ref.watch(reportSeriesProvider(period));
    final cats = ref.watch(reportCategoriesProvider(period));
    final book = ref.watch(categoryBookProvider);
    final salary = ref.watch(salaryHistoryProvider).value ?? const [];
    final due = ref.watch(shopDueProvider).value;
    if (!series.hasValue || !cats.hasValue) return (true, const [], const [], const []);

    final bars = series.value!;
    final inPeriod = _yearly ? bars : [bars.last];
    final inc = inPeriod.fold<int>(0, (a, m) => a + m.income);
    final exp = inPeriod.fold<int>(0, (a, m) => a + m.expense);
    final sav = inPeriod.fold<int>(0, (a, m) => a + m.savingsNet);
    final rem = inc - exp - math.max(0, sav);
    final kpis = <_Kpi>[
      (label: t.totalIncome, value: f.taka(inc), sub: '', color: c.successText),
      (label: t.totalExpense, value: f.taka(exp), sub: '', color: c.dangerText),
      (label: t.savings, value: f.taka(sav), sub: '${t.savingsRate} ${f.percent(inc == 0 ? 0 : sav / inc * 100)}', color: null),
      (label: t.remainingCash, value: f.taka(rem), sub: t.availHint, color: null),
    ];

    // The tapped bar, else the latest month with money, else the last.
    final selected = bars.where((m) => m.month == _selected).firstOrNull ??
        bars.where((m) => m.income > 0 || m.expense > 0).lastOrNull ??
        bars.last;
    final top = math.max(1, bars.fold<int>(0, (a, m) => math.max(a, math.max(m.income, m.expense))));

    // Top 5 categories, the rest as "Other".
    final all = cats.value!;
    final top5 = [...all.take(5)];
    if (all.length > 5) top5.add(('other', all.skip(5).fold(0, (a, x) => a + x.$2)));
    final sum = math.max(1, top5.fold<int>(0, (a, x) => a + x.$2));
    final colors = [c.accent, c.chart2, c.catTask, c.warning, c.danger, c.borderStrong];
    String catLabel(String id) => categoryInfo(t, book, TxType.expense, id).label;

    final body = <Widget>[
      DLSectionTitle(t.incVsExp),
      DLCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${f.monthYear(selected.month)}: ${f.taka(selected.income, sign: '+')} / ${f.taka(selected.expense, sign: '-')}',
                    style: DLText.textLabel.copyWith(color: c.textPrimary),
                  ),
                ),
                const SizedBox(width: DLSpace.s2),
                Text('${t.net} ${f.taka(selected.income - selected.expense)}', style: DLText.amountSm.copyWith(color: c.textSecondary)),
              ],
            ),
            const SizedBox(height: DLSpace.s2),
            DLBarChart(
              maxValue: top.toDouble(),
              selectedIndex: bars.indexOf(selected),
              onSelect: (i) => setState(() => _selected = bars[i].month),
              groups: [
                for (final (i, m) in bars.indexed)
                  DLBarGroup(
                    label: _yearly && i.isOdd ? '' : f.monthShort(m.month),
                    values: [m.income.toDouble(), m.expense.toDouble()],
                    semanticLabel: '${f.monthYear(m.month)}: ${t.income} ${f.taka(m.income)}, ${t.expense} ${f.taka(m.expense)}',
                  ),
              ],
            ),
            const SizedBox(height: DLSpace.s3),
            DLChartLegend(items: [(c.chart1, t.income), (c.chart2, t.expense)]),
          ],
        ),
      ),
      DLSectionTitle(t.catBreakdown),
      DLCard(
        child: top5.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(DLSpace.s4),
                child: Text(t.noTx, textAlign: TextAlign.center, style: DLText.textBody.copyWith(color: c.textSecondary)),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      DLDonut(
                        segments: [for (final (i, x) in top5.indexed) DLDonutSegment(value: x.$2.toDouble(), color: colors[i])],
                        semanticLabel: t.catBreakdown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(t.totalExpense, style: DLText.textCaption.copyWith(color: c.textSecondary)),
                            Text(f.taka(exp), style: DLText.amountSm.copyWith(color: c.textPrimary)),
                          ],
                        ),
                      ),
                      const SizedBox(width: DLSpace.s4),
                      Expanded(
                        child: Column(
                          children: [
                            for (final (i, x) in top5.indexed)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: DLSpace.s1),
                                child: Row(
                                  children: [
                                    DLDot(color: colors[i]),
                                    const SizedBox(width: DLSpace.s2),
                                    Expanded(
                                      child: Text(catLabel(x.$1), maxLines: 1, overflow: TextOverflow.ellipsis, style: DLText.textBodySm.copyWith(color: c.textPrimary)),
                                    ),
                                    Text(f.percent(x.$2 / sum * 100), style: DLText.amountSm.copyWith(color: c.textPrimary)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DLSpace.s3),
                  DecoratedBox(
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: c.divider))),
                    child: Column(
                      children: [
                        for (final x in top5)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: DLSpace.s2),
                            child: Row(
                              children: [
                                Expanded(child: Text(catLabel(x.$1), style: DLText.textBodySm.copyWith(color: c.textPrimary))),
                                Text(f.taka(x.$2), style: DLText.amountSm.copyWith(color: c.textPrimary)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      DLSectionTitle(t.salaryHistory, trailing: DLLinkButton(label: t.seeAll, onPressed: () => context.push(Routes.salary))),
      if (salary.isEmpty)
        DLEmptyState(inCard: true, icon: DLIcons.cash, title: t.noTx)
      else
        DLList(
          children: [
            for (final s in salary.take(3))
              DLListRow(
                minHeight: 56,
                title: t.salaryFor(f.monthYear(s.record.salaryMonth)),
                trailing: Text(f.taka(s.record.amount, sign: '+'), style: DLText.amountMd.copyWith(color: c.successText)),
              ),
          ],
        ),
      const SizedBox(height: DLSpace.s3),
      DLCard(
        onTap: () => context.push(Routes.shops),
        child: Row(
          children: [
            const DLIconChip(icon: DLIcons.store, tone: DLTone.warning),
            const SizedBox(width: DLSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.outstanding, style: DLText.textBodySm.copyWith(color: c.textSecondary)),
                  Text(f.taka(due?.total ?? 0), style: DLText.amountMd.copyWith(color: c.textPrimary)),
                ],
              ),
            ),
            Icon(DLIcons.chevronRight, size: 20, color: c.textSecondary),
          ],
        ),
      ),
    ];
    final csv = [
      for (final m in bars) [f.monthYear(m.month), '${m.income}', '${m.expense}'],
      for (final x in top5) [catLabel(x.$1), '${x.$2}'],
    ];
    return (false, kpis, body, csv);
  }

  // ---------------------------------------------------------- productivity

  (bool, List<_Kpi>, List<Widget>, List<List<String>>) _productivity(AppLocalizations t, DLColors c, DLFormat f, ReportPeriod period) {
    final tasksAsync = ref.watch(reportTasksProvider(period));
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final weekTotal = (ref.watch(weekMinutesProvider).value ?? const <String, int>{}).values.fold<int>(0, (a, b) => a + b);
    if (!tasksAsync.hasValue) return (true, const [], const [], const []);
    final tasks = tasksAsync.value!;

    final minutes = tasks.fold<int>(0, (a, k) => a + k.spentMinutes);
    final activeDays = {for (final k in tasks) if (k.spentMinutes > 0) dayKey(k.date)}.length;
    final kpis = <_Kpi>[
      (label: t.completed, value: f.count(tasks.where((k) => k.status == TaskStatus.done).length), sub: '', color: c.successText),
      (label: t.pending, value: f.count(tasks.where((k) => k.status != TaskStatus.done).length), sub: '', color: c.warningText),
      (label: t.workHours, value: f.duration(minutes), sub: '', color: null),
      (label: t.activeDays, value: f.count(activeDays), sub: '${t.avgDay} ${f.duration(activeDays == 0 ? 0 : minutes / activeDays)}', color: null),
    ];
    int spentOn(Project p) => tasks.where((k) => k.projectId == p.id).fold<int>(0, (a, k) => a + k.spentMinutes);
    final most = math.max(1, projects.fold<int>(0, (a, p) => math.max(a, spentOn(p))));
    const tones = [DLTone.accent, DLTone.teal, DLTone.warning, DLTone.success, DLTone.accent];

    final body = <Widget>[
      DLSectionTitle(t.projectPerf),
      if (projects.isEmpty)
        DLEmptyState(inCard: true, icon: DLIcons.folder, title: t.noProjects)
      else
        DLCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, p) in projects.indexed) ...[
                if (i > 0) const SizedBox(height: DLSpace.s4),
                Row(
                  children: [
                    Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: DLText.textLabel.copyWith(color: c.textPrimary))),
                    Text(f.duration(spentOn(p)), style: DLText.amountSm.copyWith(color: c.textPrimary)),
                  ],
                ),
                const SizedBox(height: DLSpace.s1),
                DLProgressBar(value: spentOn(p) / most, height: 12, tone: tones[i % tones.length]),
                const SizedBox(height: DLSpace.s1),
                Text(
                  '${t.tasksN(f.count(tasks.where((k) => k.projectId == p.id).length))} · '
                  '${t.tasksDoneN(f.count(tasks.where((k) => k.projectId == p.id && k.status == TaskStatus.done).length))}',
                  style: DLText.textCaption.copyWith(color: c.textSecondary),
                ),
              ],
            ],
          ),
        ),
      DLSectionTitle(t.workHours, trailing: Text(f.duration(weekTotal), style: DLText.amountSm.copyWith(color: c.textSecondary))),
      WeekHoursChart(color: c.catTask),
    ];
    final csv = [for (final p in projects) [p.name, '${spentOn(p)}']];
    return (false, kpis, body, csv);
  }

  // ---------------------------------------------------------- lifestyle

  (bool, List<_Kpi>, List<Widget>, List<List<String>>) _lifestyle(AppLocalizations t, DLColors c, DLFormat f) {
    final water = ref.watch(weekWaterProvider);
    final tasksAsync = ref.watch(weekTasksProvider);
    final habitsAsync = ref.watch(habitsProvider);
    final target = ref.watch(waterTargetProvider);
    if (!water.hasValue || !tasksAsync.hasValue || !habitsAsync.hasValue) return (true, const [], const [], const []);

    final today = dateOnly(ref.read(clockProvider)());
    final days = last7Days(today);
    final ml = [for (final d in days) water.value![dayKey(d)] ?? 0];
    final tasks = tasksAsync.value!;
    final habits = habitsAsync.value!;
    final met = ml.where((v) => v >= target).length;
    double habitShare(Set<String> done) => days.where((d) => done.contains(dayKey(d))).length / 7;
    final avgHabit = habits.isEmpty ? 0.0 : habits.fold<double>(0, (a, h) => a + habitShare(h.dayKeys)) / habits.length;
    int doneTasks(DateTime d) => tasks.where((k) => dayKey(k.date) == dayKey(d) && k.status == TaskStatus.done).length;
    final active = [for (final (i, d) in days.indexed) if (doneTasks(d) > 0 || ml[i] > 0) d].length;
    final most = math.max(target, ml.fold<int>(0, math.max)).toDouble();
    final metLabel = '${t.daysN(f.count(met))} / ${f.count(7)}';

    final kpis = <_Kpi>[
      (label: '${t.water} · ${t.avgDay}', value: t.ml(f.group((ml.fold<int>(0, (a, b) => a + b) / 7).round())), sub: '', color: null),
      (label: t.targetMet, value: '${t.daysN(f.count(met))}/${f.count(7)}', sub: '', color: null),
      (label: t.habitComp, value: f.percent(avgHabit * 100), sub: '', color: null),
      (label: t.activeDays, value: '${f.count(active)}/${f.count(7)}', sub: '', color: null),
    ];

    final body = <Widget>[
      DLSectionTitle(t.waterCons, trailing: DLTag(label: metLabel)),
      DLCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DLBarChart(
              height: 120,
              barAreaHeight: 100,
              maxValue: most,
              groups: [
                for (final (i, d) in days.indexed)
                  DLBarGroup(
                    label: f.weekdayShort(d),
                    values: [ml[i].toDouble()],
                    colors: [ml[i] >= target ? c.accent : c.borderStrong],
                    semanticLabel: '${f.dateLong(d)}: ${t.ml(f.group(ml[i]))}',
                  ),
              ],
            ),
            const SizedBox(height: DLSpace.s3),
            DLChartLegend(items: [(c.accent, t.targetMet), (c.borderStrong, t.remainingW)]),
          ],
        ),
      ),
      DLSectionTitle(t.habitComp),
      if (habits.isEmpty)
        DLEmptyState(inCard: true, icon: DLIcons.flame, title: t.noHabits)
      else
        DLCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, h) in habits.indexed) ...[
                if (i > 0) const SizedBox(height: DLSpace.s3),
                Row(
                  children: [
                    Expanded(child: Text(h.habit.name, style: DLText.textBodySm.copyWith(color: c.textPrimary))),
                    Text(f.percent(habitShare(h.dayKeys) * 100), style: DLText.amountSm.copyWith(color: c.textPrimary)),
                  ],
                ),
                const SizedBox(height: DLSpace.s1),
                DLProgressBar(value: habitShare(h.dayKeys), height: 6, tone: DLTone.teal),
              ],
            ],
          ),
        ),
      DLSectionTitle(t.dailyAct, trailing: Text(t.last7, style: DLText.textBodySm.copyWith(color: c.textSecondary))),
      DLList(
        children: [
          for (final (i, d) in days.indexed.toList().reversed)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: DLSpace.s4, vertical: DLSpace.s2),
                child: Row(
                  children: [
                    SizedBox(width: 84, child: Text(f.relative(d, today), style: DLText.textLabel.copyWith(color: c.textPrimary))),
                    Expanded(child: _Fact(icon: DLIcons.checkCircle, text: f.count(doneTasks(d)))),
                    Flexible(flex: 2, child: _Fact(icon: DLIcons.drop, text: t.ml(f.group(ml[i])))),
                    const SizedBox(width: DLSpace.s3),
                    Flexible(
                      child: _Fact(
                        icon: DLIcons.flame,
                        text: '${f.count(habits.where((h) => h.isDoneOn(d)).length)}/${f.count(habits.length)}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ];
    final csv = [
      for (final (i, d) in days.indexed) [dayKey(d), '${ml[i]}', '${doneTasks(d)}', '${habits.where((h) => h.isDoneOn(d)).length}'],
    ];
    return (false, kpis, body, csv);
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: c.textSecondary),
        const SizedBox(width: DLSpace.s1),
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: DLText.textBodySm.copyWith(color: c.textSecondary))),
      ],
    );
  }
}

/// Four KPI cards in two rows.
class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.kpis});

  final List<_Kpi> kpis;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    Widget card(_Kpi k) => DLCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(k.label, style: DLText.textBodySm.copyWith(color: c.textSecondary)),
              const SizedBox(height: DLSpace.s1),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(k.value, maxLines: 1, style: DLText.amountLg.copyWith(color: k.color ?? c.textPrimary)),
              ),
              if (k.sub.isNotEmpty) Text(k.sub, style: DLText.textCaption.copyWith(color: c.textSecondary)),
            ],
          ),
        );
    return Column(
      children: [
        for (var r = 0; r < kpis.length; r += 2) ...[
          if (r > 0) const SizedBox(height: DLSpace.s3),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: card(kpis[r])),
                const SizedBox(width: DLSpace.s3),
                Expanded(child: r + 1 < kpis.length ? card(kpis[r + 1]) : const SizedBox()),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
