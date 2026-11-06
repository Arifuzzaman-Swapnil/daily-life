import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs/dashboard_layout.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';

/// Opens "Customize dashboard" (screenshot 07).
Future<void> showCustomizeSheet(BuildContext context) {
  final t = AppLocalizations.of(context);
  return showDLSheet<void>(context, title: t.customize, subtitle: t.custSub, builder: (_) => const CustomizeSheet());
}

/// Each Home section with a show/hide switch and up/down arrows. Changes apply
/// and are saved at once; Done closes the sheet with a toast.
class CustomizeSheet extends ConsumerWidget {
  const CustomizeSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final layout = ref.watch(dashboardLayoutProvider);
    final edit = ref.read(dashboardLayoutProvider.notifier);
    String label(DashSection s) => switch (s) {
          DashSection.summary => t.secSummary,
          DashSection.chart => t.secChart,
          DashSection.today => t.todayOverview,
          DashSection.shop => t.outstanding,
          DashSection.quick => t.quick,
          DashSection.recent => t.recentTx,
        };
    final last = layout.order.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DLList(
          outlined: true,
          children: [
            for (final (i, s) in layout.order.indexed)
              Padding(
                padding: const EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s2, DLSpace.s2, DLSpace.s2),
                child: Row(
                  children: [
                    DLSwitch(value: layout.isShown(s), semanticLabel: label(s), onChanged: (on) => edit.setShown(s, on)),
                    const SizedBox(width: DLSpace.s3),
                    Expanded(child: Text(label(s), style: DLText.textBody.copyWith(color: c.textPrimary))),
                    DLIconButton(
                      icon: DLIcons.chevronUp,
                      tooltip: t.moveUp,
                      iconSize: 20,
                      onPressed: i == 0 ? null : () => edit.move(s, -1),
                    ),
                    DLIconButton(
                      icon: DLIcons.chevronDown,
                      tooltip: t.moveDown,
                      iconSize: 20,
                      onPressed: i == last ? null : () => edit.move(s, 1),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: DLSpace.s4),
        DLButton(
          label: t.done,
          onPressed: () {
            DLToast.show(context, t.dashSaved);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
