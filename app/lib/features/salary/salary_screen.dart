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
import '../finance/money_providers.dart';

/// Salary management (prototype `salary`, screenshot 18): monthly salary,
/// last and next pay, the last 6 salaries, and the history with raises.
class SalaryScreen extends ConsumerWidget {
  const SalaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final today = dateOnly(ref.watch(clockProvider)());
    final config = ref.watch(salaryConfigProvider).value;
    final history = ref.watch(salaryHistoryProvider).value ?? const [];
    final last = history.firstOrNull?.record;
    final next = config?.nextExpectedDate;
    final nextIn = next?.difference(today).inDays;
    final chart = history.take(6).toList().reversed.toList();

    Widget tileText(String text, {TextStyle? style, Color? color}) =>
        Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: (style ?? DLText.textCaption).copyWith(color: color ?? c.brandMuted));

    return Scaffold(
      appBar: DLAppBar(
        title: t.salaryMgmt,
        onLeading: () => popOr(context, Routes.finance),
        actions: [DLIconButton(icon: DLIcons.plus, tooltip: t.addSalary, onPressed: () => context.push(Routes.addSalary))],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          DLHero(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.monthlySalary, style: DLText.textLabel.copyWith(color: c.brandMuted)),
                const SizedBox(height: DLSpace.s1),
                Text(f.taka(config?.monthlyAmount ?? 0), style: DLText.amountHero.copyWith(color: c.onBrand)),
                const SizedBox(height: DLSpace.s4),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: DLHeroTile(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              tileText(t.lastSalary),
                              tileText(last == null ? '—' : f.taka(last.amount), style: DLText.amountSm, color: c.onBrand),
                              if (last != null) tileText(f.dateMedium(last.paidDate)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: DLSpace.s3),
                      Expanded(
                        child: DLHeroTile(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              tileText(t.nextSalary),
                              tileText(next == null ? '—' : f.dateMedium(next), style: DLText.amountSm, color: c.onBrand),
                              if (nextIn != null && nextIn >= 0) tileText(t.inDays(f.count(nextIn)), color: c.onBrandAccent),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DLSpace.s3),
          Row(
            children: [
              Expanded(child: DLButton(label: t.addSalary, icon: DLIcons.plus, onPressed: () => context.push(Routes.addSalary))),
              const SizedBox(width: DLSpace.s2),
              Expanded(
                child: DLButton(
                  label: t.allocateNow,
                  icon: DLIcons.pie,
                  variant: DLButtonVariant.secondary,
                  onPressed: () => context.push(Routes.allocation),
                ),
              ),
            ],
          ),
          DLSectionTitle(t.monthCompare),
          DLCard(
            child: DLBarChart(
              height: 130,
              barAreaHeight: 90,
              colors: [c.chart1],
              groups: [
                for (final h in chart)
                  DLBarGroup(
                    label: f.monthShort(h.record.salaryMonth),
                    values: [h.record.amount.toDouble()],
                    valueLabel: f.takaCompact(h.record.amount),
                    semanticLabel: '${f.monthYear(h.record.salaryMonth)}: ${f.taka(h.record.amount)}',
                  ),
              ],
            ),
          ),
          DLSectionTitle(t.salaryHistory),
          if (history.isEmpty)
            DLEmptyState(
              inCard: true,
              icon: DLIcons.cash,
              title: t.noHist,
              actionLabel: t.addSalary,
              onAction: () => context.push(Routes.addSalary),
            )
          else
            DLList(
              children: [
                for (final h in history)
                  DLListRow(
                    leading: const DLIconChip(icon: DLIcons.cash, tone: DLTone.success),
                    title: t.salaryFor(f.monthYear(h.record.salaryMonth)),
                    subtitle: '${f.dateMedium(h.record.paidDate)} · ${paymentLabel(t, h.record.method)}',
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(f.taka(h.record.amount, sign: '+'), style: DLText.amountMd.copyWith(color: c.successText)),
                        if (h.raise case final raise?) DLTag(label: '${t.raise} ${f.taka(raise, sign: '+')}', tone: DLTone.success),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
