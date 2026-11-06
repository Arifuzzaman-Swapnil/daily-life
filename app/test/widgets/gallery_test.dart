// Every DL component on one page at the smallest supported phone width (360dp),
// in Bengali and English × Light and Dark. Fails on any overflow or exception.
import 'package:dailylife/core/theme/dl_tokens.dart';
import 'package:dailylife/core/widgets/dl_widgets.dart';
import 'package:dailylife/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

Widget gallery(AppLocalizations t) {
  void noop() {}
  void pick(Object? _) {}
  return Builder(
    builder: (context) {
      final c = context.dl;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DLAppBar.root(title: t.finance, actions: [DLIconButton(icon: DLIcons.gear, tooltip: t.settings, onPressed: noop)]),
          DLAppBar(
            title: t.addIncome,
            leading: DLAppBarLeading.close,
            onLeading: noop,
            actions: [DLIconButton(icon: DLIcons.trash, tooltip: t.del, onPressed: noop)],
          ),
          DLBalanceHero(
            label: t.available,
            amount: '৳১,২৫,৪৮০',
            hint: t.availHint,
            trailing: DLHeroPill(label: t.monthSel, onTap: noop),
            stats: [
              DLHeroStat(icon: DLIcons.wallet, label: t.totalIncome, amount: '৳৫০,০০০', onTap: noop),
              DLHeroStat(icon: DLIcons.wallet, label: t.totalExpense, amount: '৳২২,৮৮০', onTap: noop),
            ],
          ),
          DLSectionTitle(t.recentTx, trailing: DLLinkButton(label: t.seeAll, onPressed: noop)),
          DLList(
            children: [
              DLListRow(
                leading: const DLIconChip(icon: DLIcons.wallet, tone: DLTone.success),
                title: t.incSaved,
                subtitle: '${t.category} · ${t.income}',
                trailing: Text('+৳৮৫,০০০', style: DLText.amountMd.copyWith(color: c.income)),
                onTap: noop,
              ),
              DLListRow(title: t.customize, subtitle: t.availHint, trailing: DLSwitch(value: true, onChanged: pick)),
              DLKeyValueRow(label: t.method, value: t.income),
            ],
          ),
          const SizedBox(height: 12),
          DLCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DLBarChart(
                  selectedIndex: 5,
                  onSelect: pick,
                  groups: [
                    for (final (i, m) in ['জুন', 'জুলা', 'আগ', 'সেপ্টে', 'অক্টো', 'নভে'].indexed)
                      DLBarGroup(label: m, values: [50000.0 - i * 1000, 22880.0 + i * 500], semanticLabel: m),
                  ],
                ),
                const SizedBox(height: 12),
                DLChartLegend(items: [(c.chart1, t.income), (c.chart2, t.expense)]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DLCard(
            child: Row(
              children: [
                DLDonut(
                  segments: [
                    DLDonutSegment(value: 44, color: c.chart1),
                    DLDonutSegment(value: 22, color: c.chart2),
                    DLDonutSegment(value: 20, color: c.chart3),
                    DLDonutSegment(value: 14, color: c.chart4),
                  ],
                  child: Text('৳২২,৮৮০', style: DLText.amountSm.copyWith(color: c.textPrimary)),
                ),
                const SizedBox(width: 16),
                Expanded(child: DLChartLegend(items: [(c.chart1, t.catBreakdown), (c.chart3, t.expense)])),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DLSegmentedTabs<int>(value: 0, options: [(0, t.income), (1, t.expense)], onChanged: pick),
          const SizedBox(height: 12),
          DLSegmentedTabs<int>(value: 1, expand: false, options: [(0, t.income), (1, t.expense)], onChanged: pick),
          Wrap(
            spacing: 8,
            children: [
              DLChip(label: t.income, icon: DLIcons.wallet, selected: true, onTap: noop),
              DLChip(label: t.expense, onTap: noop),
              DLChip(label: t.newCat, icon: DLIcons.plus, dashed: true, onTap: noop),
              DLChip(label: t.income, trailingIcon: DLIcons.close, selected: true, onTap: noop),
              DLChip(label: '${t.noTx} ${t.noTxSub}', icon: DLIcons.wallet, onTap: noop),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DLTag(label: t.income, tone: DLTone.success),
              DLTag(label: t.expense, tone: DLTone.danger),
              DLTag(label: t.totalSavings, tone: DLTone.teal),
              const DLBadge('৯'),
              DLDot(color: c.danger, size: 10, ring: c.background),
            ],
          ),
          const SizedBox(height: 16),
          DLTextField(label: t.amount, amount: true, hint: '০', error: t.errForm),
          DLTextField(label: t.optNote, optionalLabel: t.optional, hint: t.phNote),
          DLTextField(label: t.category, multiline: true, hint: t.noTxSub, helper: t.availHint),
          DLSelect<int>(label: t.method, value: 0, options: [(0, t.income), (1, t.expense)], onChanged: pick),
          DLSearchBar(hint: t.searchTx),
          Row(
            children: [
              DLSwitch(value: true, onChanged: pick),
              DLSwitch(value: false, onChanged: pick),
              DLCheckbox(value: true, onChanged: pick),
              DLCheckbox(value: false, round: true, onChanged: pick),
            ],
          ),
          const DLProgressBar(value: 0.86, tone: DLTone.warning),
          const SizedBox(height: 12),
          const Center(child: DLProgressRing(value: 0.5, child: Text('৫০%'))),
          const SizedBox(height: 12),
          const DLSkeleton(height: 84),
          const SizedBox(height: 12),
          DLEmptyState(icon: DLIcons.wallet, title: t.noTx, body: t.noTxSub, actionLabel: t.addIncome, onAction: noop, inCard: true),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: DLButton(label: t.cancel, variant: DLButtonVariant.secondary, onPressed: noop)),
              const SizedBox(width: 8),
              Expanded(child: DLButton(label: t.save, onPressed: noop)),
            ],
          ),
          const SizedBox(height: 12),
          DLButton(label: t.customize, icon: DLIcons.plus, variant: DLButtonVariant.tonal, size: DLButtonSize.md, onPressed: noop),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight, child: DLFab(tooltip: t.add, onPressed: noop)),
          const SizedBox(height: 12),
          DLSheet(title: t.filters, subtitle: t.customize, child: Text(t.noTxSub)),
          SizedBox(height: 420, child: DLConfirmDialog(title: t.delTxQ, body: '৳৪,২০০ · ${t.noTxSub}')),
        ],
      );
    },
  );
}

void main() {
  for (final lang in ['bn', 'en']) {
    for (final dark in [false, true]) {
      testWidgets('every component lays out at 360dp: $lang, ${dark ? 'dark' : 'light'}', (tester) async {
        final t = lookupAppLocalizations(Locale(lang));
        await pumpDL(tester, gallery(t), dark: dark, lang: lang, width: 360, height: 800, reduceMotion: true);
        expect(tester.takeException(), isNull);

        // Grounds follow the theme.
        final c = colorsOf(tester);
        expect(c.background, (dark ? DLColors.dark : DLColors.light).background);
        final list = tester.widget<DecoratedBox>(find.descendant(of: find.byType(DLList), matching: find.byType(DecoratedBox)).first);
        expect((list.decoration as BoxDecoration).color, c.surface);
        expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor ?? Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor, c.background);
      });
    }
  }
}
