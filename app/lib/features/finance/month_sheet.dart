import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/format_provider.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import 'money_providers.dart';

/// Opens the month picker (screenshot 06). Home and Finance share it, and the
/// month: picking one sets [selectedMonthProvider].
Future<void> showMonthSheet(BuildContext context) =>
    showDLSheet<void>(context, title: AppLocalizations.of(context).monthSel, builder: (_) => const MonthSheet());

/// Month picker sheet: the last 6 months, newest first, each with its net.
class MonthSheet extends ConsumerWidget {
  const MonthSheet({super.key});

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
