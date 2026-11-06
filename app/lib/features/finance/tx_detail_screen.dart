import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';
import '../../core/format/dl_format_more.dart';
import '../../core/format/format_provider.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import 'categories.dart';
import 'money_providers.dart';

/// Transaction details (prototype `txDetail`, screenshot 13) with edit and
/// delete (dialog 14). A shop-credit payment links to its shop.
class TxDetailScreen extends ConsumerWidget {
  const TxDetailScreen({super.key, required this.id});

  final String id;

  Future<void> _delete(BuildContext context, WidgetRef ref, Txn x) async {
    final t = AppLocalizations.of(context);
    final f = ref.read(formatProvider);
    final ok = await showDLConfirm(context, title: t.delTxQ, body: '${f.taka(x.amount)} · ${x.title}. ${t.delB}');
    if (!ok || !context.mounted) return;
    await ref.read(financeDaoProvider).deleteTransaction(x.id);
    if (!context.mounted) return;
    DLToast.show(context, t.txDeleted);
    popOr(context, Routes.finance);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final x = ref.watch(transactionProvider(id)).value;
    final book = ref.watch(categoryBookProvider);
    final allocations = ref.watch(allocationsProvider).value ?? const [];
    final shops = ref.watch(shopsProvider).value ?? const [];

    final actions = x == null
        ? const <Widget>[]
        : [
            DLIconButton(icon: DLIcons.edit, tooltip: t.edit, onPressed: () => context.push(Routes.editTx(x.id))),
            DLIconButton(icon: DLIcons.trash, tooltip: t.del, onPressed: () => _delete(context, ref, x)),
          ];
    final appBar = DLAppBar(title: t.txDetail, actions: actions, onLeading: () => popOr(context, Routes.finance));
    if (x == null) return Scaffold(appBar: appBar, body: const SizedBox.shrink());

    final income = x.type == TxType.income;
    final info = categoryInfo(t, book, x.type, x.categoryId);
    final allocation = allocations.where((a) => a.id == x.allocationId).firstOrNull;
    final shop = x.shopId == null ? null : shops.where((s) => s.shop.id == x.shopId).firstOrNull?.shop;
    final rows = <(String, String)>[
      (t.type, income ? t.income : t.expense),
      (t.category, info.label),
      (t.date, f.dateLongYear(x.date)),
      (t.time, f.time(x.time)),
      (t.method, paymentLabel(t, x.paymentMethod)),
      if (!income) (t.budgetCat, allocation == null ? t.none : allocation.name),
      if (x.description.isNotEmpty) (t.desc, x.description),
      if (x.note.isNotEmpty) (t.note, x.note),
    ];

    return Scaffold(
      appBar: appBar,
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          DLCard(
            padding: const EdgeInsets.symmetric(horizontal: DLSpace.s4, vertical: DLSpace.s6),
            child: Column(
              children: [
                DLIconChip(icon: income ? DLIcons.income : info.icon, tone: income ? DLTone.success : DLTone.danger, size: 56),
                const SizedBox(height: DLSpace.s2),
                Text(
                  f.taka(x.amount, sign: income ? '+' : '-'),
                  style: DLText.amountLg.copyWith(color: income ? c.successText : c.dangerText),
                ),
                const SizedBox(height: DLSpace.s2),
                Text(x.title, textAlign: TextAlign.center, style: DLText.textH3.copyWith(color: c.textPrimary)),
                const SizedBox(height: DLSpace.s2),
                DLTag(label: info.label, tone: income ? DLTone.success : DLTone.neutral),
              ],
            ),
          ),
          const SizedBox(height: DLSpace.s3),
          DLList(children: [for (final (k, v) in rows) DLKeyValueRow(label: k, value: v)]),
          if (shop != null) ...[
            const SizedBox(height: DLSpace.s3),
            DLList(
              children: [
                DLListRow(
                  leading: const DLIconChip(icon: DLIcons.store, tone: DLTone.warning),
                  title: shop.name,
                  trailing: Icon(DLIcons.chevronRight, size: 20, color: c.textSecondary),
                  onTap: () => context.push(Routes.shop(shop.id)),
                ),
              ],
            ),
          ],
          const SizedBox(height: DLSpace.s6),
          Row(
            children: [
              Expanded(
                child: DLButton(
                  label: t.del,
                  icon: DLIcons.trash,
                  variant: DLButtonVariant.secondary,
                  onPressed: () => _delete(context, ref, x),
                ),
              ),
              const SizedBox(width: DLSpace.s2),
              Expanded(child: DLButton(label: t.edit, icon: DLIcons.edit, onPressed: () => context.push(Routes.editTx(x.id)))),
            ],
          ),
        ],
      ),
    );
  }
}
