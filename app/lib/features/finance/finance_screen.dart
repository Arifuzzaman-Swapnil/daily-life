import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import '../../core/format/dl_format.dart';
import '../../core/format/dl_format_more.dart';
import '../../core/format/format_provider.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import 'categories.dart';
import 'money_providers.dart';

/// Finance tab (prototype `finance`, screenshot 10): month switcher, remaining
/// balance, savings and shop-credit cards, tools, and the month's transactions
/// with tabs, search and filters (sheet 11). The + button opens the add sheet (12).
class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  late final TextEditingController _search = TextEditingController(text: ref.read(finFilterProvider).query);

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
    final month = ref.watch(selectedMonthProvider);
    final months = ref.read(selectedMonthProvider.notifier);
    final filter = ref.watch(finFilterProvider);
    final filters = ref.read(finFilterProvider.notifier);
    final totals = ref.watch(monthTotalsProvider(month)).value;
    final savings = ref.watch(savingsTotalProvider).value ?? 0;
    final owed = ref.watch(shopDueProvider).value?.total ?? 0;
    final book = ref.watch(categoryBookProvider);
    final txns = ref.watch(monthTransactionsProvider(month)).value;
    final hasAny = ref.watch(hasTransactionsProvider).value;
    final today = dateOnly(ref.watch(clockProvider)());
    final bottom = MediaQuery.paddingOf(context).bottom;

    // "Clear filters" elsewhere also clears the search box.
    ref.listen(finFilterProvider.select((s) => s.query), (_, q) {
      if (_search.text != q) _search.text = q;
    });

    String catLabel(Txn x) => categoryInfo(t, book, x.type, x.categoryId).label;
    final list = txns == null || book.isEmpty ? null : filter.apply(txns, today, catLabel);

    final children = <Widget>[
      _MonthSwitcher(
        label: f.monthYear(month),
        onBack: months.canGoBack ? months.back : null,
        onForward: months.canGoForward ? months.forward : null,
        onPick: () => showDLSheet<void>(context, title: t.monthSel, builder: (_) => const _MonthSheet()),
      ),
      const SizedBox(height: DLSpace.s3),
      DLBalanceHero(
        label: t.remaining,
        amount: f.taka(totals?.available ?? 0),
        stats: [
          DLHeroStat(icon: DLIcons.income, label: t.totalIncome, amount: f.taka(totals?.income ?? 0), onTap: () => filters.setTab(FinTab.income)),
          DLHeroStat(icon: DLIcons.expense, label: t.totalExpense, amount: f.taka(totals?.expense ?? 0), onTap: () => filters.setTab(FinTab.expense)),
        ],
      ),
      const SizedBox(height: DLSpace.s3),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _StatCard(
                icon: DLIcons.piggy,
                tone: DLTone.success,
                label: t.totalSavings,
                amount: f.taka(savings),
                onTap: () => context.push(Routes.savings),
              ),
            ),
            const SizedBox(width: DLSpace.s3),
            Expanded(
              child: _StatCard(
                icon: DLIcons.store,
                tone: DLTone.warning,
                label: t.shopCredit,
                amount: f.taka(owed),
                onTap: () => context.push(Routes.shops),
              ),
            ),
          ],
        ),
      ),
      DLSectionTitle(t.tools),
      _ToolGrid(
        tools: [
          (DLIcons.cash, DLTone.accent, t.salaryMgmt, Routes.salary),
          (DLIcons.pie, DLTone.teal, t.allocation, Routes.allocation),
          (DLIcons.piggy, DLTone.success, t.savings, Routes.savings),
          (DLIcons.store, DLTone.warning, t.shopCredit, Routes.shops),
          (DLIcons.tag, DLTone.neutral, t.categories, Routes.categories),
          (DLIcons.chart, DLTone.accent, t.reports, Routes.reports),
        ],
      ),
      const SizedBox(height: DLSpace.s6),
      DLSegmentedTabs<FinTab>(
        value: filter.tab,
        options: [(FinTab.all, t.all), (FinTab.income, t.income), (FinTab.expense, t.expense)],
        onChanged: filters.setTab,
      ),
      const SizedBox(height: DLSpace.s3),
      Row(
        children: [
          Expanded(child: DLSearchBar(hint: t.searchTx, controller: _search, onChanged: filters.setQuery)),
          const SizedBox(width: DLSpace.s2),
          Stack(
            clipBehavior: Clip.none,
            children: [
              DLIconButton(
                icon: DLIcons.filter,
                tooltip: t.filters,
                tonal: true,
                size: DLSize.touch,
                onPressed: () => showDLSheet<void>(context, title: t.filters, builder: (_) => const _FilterSheet()),
              ),
              if (filter.activeCount > 0) Positioned(top: -4, right: -4, child: IgnorePointer(child: DLBadge(f.count(filter.activeCount)))),
            ],
          ),
        ],
      ),
      if (filter.activeCount > 0) ...[
        const SizedBox(height: DLSpace.s3),
        _ActiveFilters(filter: filter, book: book),
      ],
      if (list != null && list.isNotEmpty) ...[
        const SizedBox(height: DLSpace.s3),
        Row(
          children: [
            Expanded(child: Text(t.resultsN(f.count(list.length)), style: DLText.textBodySm.copyWith(color: c.textSecondary))),
            Text(
              f.taka(list.fold<int>(0, (sum, x) => sum + (x.type == TxType.income ? x.amount : -x.amount))),
              style: DLText.amountSm.copyWith(color: c.textSecondary),
            ),
          ],
        ),
        ..._groups(f, list, book, today),
      ],
      if (list != null && list.isEmpty && hasAny == true) ...[
        const SizedBox(height: DLSpace.s3),
        DLEmptyState(
          inCard: true,
          icon: DLIcons.search,
          title: t.noMatch,
          body: t.noMatchSub,
          actionLabel: t.clearFilters,
          actionVariant: DLButtonVariant.secondary,
          onAction: filters.clearAll,
        ),
      ],
      if (hasAny == false) ...[
        const SizedBox(height: DLSpace.s3),
        DLEmptyState(
          inCard: true,
          icon: DLIcons.wallet,
          title: t.noTx,
          body: t.noTxSub,
          actionLabel: t.addIncome,
          onAction: () => context.push(Routes.newTx(TxType.income)),
          secondaryLabel: t.addExpense,
          onSecondary: () => context.push(Routes.newTx(TxType.expense)),
        ),
      ],
    ];

    return Stack(
      children: [
        Column(
          children: [
            DLAppBar.root(
              title: t.finance,
              actions: [
                DLIconButton(icon: DLIcons.tag, tooltip: t.categories, onPressed: () => context.push(Routes.categories)),
                DLIconButton(icon: DLIcons.chart, tooltip: t.reports, onPressed: () => context.push(Routes.reports)),
              ],
            ),
            Expanded(
              child: ListView(
                // Room under the last row for the + button.
                padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, bottom + DLSize.fab + DLSpace.s8),
                children: children,
              ),
            ),
          ],
        ),
        Positioned(
          right: DLSpace.s4,
          bottom: bottom + DLSpace.s4,
          child: DLFab(tooltip: t.add, onPressed: () => showDLSheet<void>(context, title: t.add, builder: (_) => _AddSheet(parent: context))),
        ),
      ],
    );
  }

  /// Day headings ("আজ · ৬ নভেম্বর, শুক্রবার") over each day's rows.
  List<Widget> _groups(DLFormat f, List<Txn> list, CategoryBook book, DateTime today) {
    final out = <Widget>[];
    var i = 0;
    while (i < list.length) {
      final day = list[i].date;
      final rows = <Txn>[];
      while (i < list.length && list[i].date == day) {
        rows.add(list[i++]);
      }
      final diff = day.difference(today).inDays;
      final rel = diff == 0 || diff == -1 ? '${f.relative(day, today)} · ' : '';
      out
        ..add(DLSectionHeader('$rel${f.dateLong(day)}', first: true))
        ..add(DLList(children: [for (final x in rows) TxRow(x: x, book: book)]));
    }
    return out;
  }
}

/// A transaction in a list (prototype `.li` from `txView`): icon tile, title,
/// "category · time · method", signed amount. Opens the details.
class TxRow extends ConsumerWidget {
  const TxRow({super.key, required this.x, required this.book});

  final Txn x;
  final CategoryBook book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final info = categoryInfo(t, book, x.type, x.categoryId);
    final icon = txIcon(x, info);
    final income = x.type == TxType.income;
    return DLListRow(
      leading: DLIconChip(icon: icon.icon, tone: icon.tone),
      title: x.title,
      subtitle: '${info.label} · ${f.time(x.time)} · ${paymentLabel(t, x.paymentMethod)}',
      trailing: Text(
        f.taka(x.amount, sign: income ? '+' : '-'),
        style: DLText.amountMd.copyWith(color: income ? c.successText : c.dangerText),
      ),
      onTap: () => context.push(Routes.tx(x.id)),
    );
  }
}

class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({required this.label, required this.onBack, required this.onForward, required this.onPick});

  final String label;
  final VoidCallback? onBack;
  final VoidCallback? onForward;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    return Row(
      children: [
        DLIconButton(icon: DLIcons.chevronLeft, tooltip: t.prevMonth, onPressed: onBack),
        Expanded(
          child: Center(
            child: DLPressable(
              onTap: onPick,
              semanticLabel: '${t.monthSel}: $label',
              excludeSemantics: true,
              borderRadius: const BorderRadius.all(Radius.circular(DLRadius.sm)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: DLSize.touch),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DLSpace.s2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: DLText.textH3.copyWith(color: c.textPrimary))),
                      const SizedBox(width: DLSpace.s1),
                      Icon(DLIcons.chevronDown, size: 20, color: c.textPrimary),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        DLIconButton(icon: DLIcons.chevronRight, tooltip: t.nextMonth, onPressed: onForward),
      ],
    );
  }
}

/// Savings / shop-credit summary card under the hero.
class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.tone, required this.label, required this.amount, required this.onTap});

  final IconData icon;
  final DLTone tone;
  final String label;
  final String amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    return DLCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              DLIconChip(icon: icon, tone: tone, size: 36),
              const SizedBox(width: DLSpace.s2),
              Expanded(child: Text(label, style: DLText.textBodySm.copyWith(color: c.textSecondary))),
            ],
          ),
          const SizedBox(height: DLSpace.s1),
          Text(amount, style: DLText.amountMd.copyWith(color: c.textPrimary)),
        ],
      ),
    );
  }
}

/// The 3-column tools grid (prototype `.g3` of `.card.tool`).
class _ToolGrid extends StatelessWidget {
  const _ToolGrid({required this.tools});

  final List<(IconData, DLTone, String, String)> tools;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    Widget tool((IconData, DLTone, String, String) x) => DLCard(
          onTap: () => context.push(x.$4),
          padding: const EdgeInsets.all(DLSpace.s3),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DLIconChip(icon: x.$1, tone: x.$2, size: 36),
                const SizedBox(height: DLSpace.s2),
                Text(x.$3, style: DLText.textBodySm.copyWith(fontWeight: FontWeight.w500, color: c.textPrimary)),
              ],
            ),
          ),
        );
    return Column(
      children: [
        for (var r = 0; r < tools.length; r += 3) ...[
          if (r > 0) const SizedBox(height: DLSpace.s3),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = r; i < r + 3; i++) ...[
                  if (i > r) const SizedBox(width: DLSpace.s3),
                  Expanded(child: i < tools.length ? tool(tools[i]) : const SizedBox.shrink()),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Removable chips for the active filters, in a sideways-scrolling row.
class _ActiveFilters extends ConsumerWidget {
  const _ActiveFilters({required this.filter, required this.book});

  final FinFilter filter;
  final CategoryBook book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final filters = ref.read(finFilterProvider.notifier);
    final chips = <(String, VoidCallback)>[
      if (filter.range != FinRange.month) (filter.range == FinRange.today ? t.rToday : t.r7, () => filters.setRange(FinRange.month)),
      if (filter.category case final cat?) (categoryInfo(t, book, cat.$1, cat.$2).label, filters.clearCategory),
      if (filter.method case final m?) (paymentLabel(t, m), filters.clearMethod),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final (i, (label, clear)) in chips.indexed) ...[
            if (i > 0) const SizedBox(width: DLSpace.s2),
            DLChip(label: label, selected: true, trailingIcon: DLIcons.close, semanticLabel: '${t.reset}: $label', onTap: clear),
          ],
        ],
      ),
    );
  }
}

/// Month picker sheet: the last 6 months with each month's net.
class _MonthSheet extends ConsumerWidget {
  const _MonthSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final selected = ref.watch(selectedMonthProvider);
    final series = ref.watch(monthlySeriesProvider(6)).value ?? const [];
    return DLList(
      outlined: true,
      children: [
        for (final m in series.reversed)
          DLListRow(
            minHeight: 56,
            title: f.monthYear(m.month),
            titleStyle: DLText.textBodyLg,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(f.taka(m.income - m.expense), style: DLText.amountSm.copyWith(color: c.textSecondary)),
                if (m.month == selected) ...[
                  const SizedBox(width: DLSpace.s2),
                  Icon(DLIcons.check, size: DLSize.icon, color: c.accentText),
                ],
              ],
            ),
            onTap: () {
              ref.read(selectedMonthProvider.notifier).show(m.month);
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}

/// "Add" sheet (screenshot 12): income, expense, salary, shop purchase.
class _AddSheet extends StatelessWidget {
  const _AddSheet({required this.parent});

  /// The Finance page, which stays mounted under the sheet.
  final BuildContext parent;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final router = GoRouter.of(parent);
    void open(String route) {
      Navigator.of(context).pop();
      router.push(route);
    }

    Widget bigCard(IconData icon, DLTone tone, String label, String route) => DLCard(
          outlined: true,
          onTap: () => open(route),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DLIconChip(icon: icon, tone: tone),
                const SizedBox(height: DLSpace.s2),
                Text(label, style: DLText.textH3.copyWith(color: c.textPrimary)),
              ],
            ),
          ),
        );

    Widget row(IconData icon, DLTone tone, String label, String route) => DLListRow(
          leading: DLIconChip(icon: icon, tone: tone),
          title: label,
          trailing: Icon(DLIcons.chevronRight, size: 20, color: c.textSecondary),
          onTap: () => open(route),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: bigCard(DLIcons.income, DLTone.success, t.addIncome, Routes.newTx(TxType.income))),
              const SizedBox(width: DLSpace.s3),
              Expanded(child: bigCard(DLIcons.expense, DLTone.danger, t.addExpense, Routes.newTx(TxType.expense))),
            ],
          ),
        ),
        const SizedBox(height: DLSpace.s3),
        DLList(
          outlined: true,
          children: [
            row(DLIcons.cash, DLTone.accent, t.addSalary, Routes.addSalary),
            row(DLIcons.store, DLTone.warning, t.addPurchase, Routes.shops),
          ],
        ),
      ],
    );
  }
}

/// Filter sheet (screenshot 11). Choices apply at once; Apply closes, Reset
/// clears the search and every filter.
class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final filter = ref.watch(finFilterProvider);
    final filters = ref.read(finFilterProvider.notifier);
    final book = ref.watch(categoryBookProvider);

    // The prototype's list: expense categories (+ shop payments) unless on the
    // Income tab, then income categories unless on the Expense tab; one chip per id.
    final cats = <(TxType, String)>[
      if (filter.tab != FinTab.income) ...[for (final x in book.pickable(TxType.expense)) (TxType.expense, x.id), (TxType.expense, kShopCategory)],
      if (filter.tab != FinTab.expense) for (final x in book.pickable(TxType.income)) (TxType.income, x.id),
    ];
    final seen = <String>{};
    cats.retainWhere((x) => seen.add(x.$2));

    Widget label(String text, {double top = DLSpace.s5}) => Padding(
          padding: EdgeInsets.only(top: top, bottom: DLSpace.s2),
          child: Text(text, style: DLText.textLabel.copyWith(color: c.textPrimary)),
        );
    Widget chips(List<Widget> children) => Wrap(spacing: DLSpace.s2, runSpacing: 0, children: children);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label(t.dateRange, top: 0),
        chips([
          for (final (r, l) in [(FinRange.month, t.rMonth), (FinRange.last7, t.r7), (FinRange.today, t.rToday)])
            DLChip(label: l, selected: filter.range == r, onTap: () => filters.setRange(r)),
        ]),
        label(t.category),
        chips([
          for (final cat in cats)
            DLChip(
              label: categoryInfo(t, book, cat.$1, cat.$2).label,
              selected: filter.category?.$2 == cat.$2,
              onTap: () => filters.toggleCategory(cat),
            ),
        ]),
        label(t.method),
        chips([
          for (final m in PaymentMethod.values) DLChip(label: paymentLabel(t, m), selected: filter.method == m, onTap: () => filters.toggleMethod(m)),
        ]),
        const SizedBox(height: DLSpace.s6),
        Row(
          children: [
            Expanded(
              child: DLButton(
                label: t.reset,
                variant: DLButtonVariant.secondary,
                onPressed: () {
                  filters.clearAll();
                  Navigator.of(context).pop();
                },
              ),
            ),
            const SizedBox(width: DLSpace.s2),
            Expanded(child: DLButton(label: t.apply, onPressed: () => Navigator.of(context).pop())),
          ],
        ),
      ],
    );
  }
}
