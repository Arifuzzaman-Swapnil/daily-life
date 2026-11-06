import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/daos/shop_dao.dart';
import '../../core/db/db_providers.dart';
import '../../core/format/dl_format.dart';
import '../../core/format/dl_format_more.dart';
import '../../core/format/format_provider.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../finance/money_providers.dart';

enum _EntryTab { all, buy, pay }

/// A shop's credit (prototype `shopDetail`, screenshot 25): previous balance +
/// new purchases − paid = now due, purchase / payment (sheet 26) / settle in
/// full, and the history with a running balance.
class ShopDetailScreen extends ConsumerStatefulWidget {
  const ShopDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends ConsumerState<ShopDetailScreen> {
  _EntryTab _tab = _EntryTab.all;

  Future<void> _delete(Shop shop) async {
    final t = AppLocalizations.of(context);
    final ok = await showDLConfirm(context, title: '${t.del}?', body: shop.name);
    if (!ok || !mounted) return;
    await ref.read(shopDaoProvider).deleteShop(shop.id);
    if (mounted) popOr(context, Routes.shops);
  }

  Future<void> _settle(ShopDetail d) async {
    final t = AppLocalizations.of(context);
    final f = ref.read(formatProvider);
    final ok = await showDLConfirm(
      context,
      title: t.settleQ,
      body: t.settleB(f.taka(d.balance)),
      confirmLabel: t.confirm,
      safe: true,
    );
    if (!ok || !mounted) return;
    await ref.read(shopDaoProvider).settle(shopId: d.shop.id, date: dateOnly(ref.read(clockProvider)()), title: t.payTo(d.shop.name));
    if (mounted) DLToast.show(context, t.paymentSaved);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final d = ref.watch(shopDetailProvider(widget.id)).value;
    if (d == null) {
      return Scaffold(appBar: DLAppBar(title: '', onLeading: () => popOr(context, Routes.shops)), body: const SizedBox.shrink());
    }
    final owes = d.balance > 0;
    final entries = [
      for (final line in d.entries.reversed)
        if (_tab == _EntryTab.all || line.entry.type.name == _tab.name) line,
    ];

    Widget kv(String label, String value, {Color? color, bool strong = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: DLSpace.s4, vertical: DLSpace.s3),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: c.divider, width: strong ? 2 : 1))),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: strong
                      ? DLText.textBody.copyWith(fontWeight: FontWeight.w600, color: c.textPrimary)
                      : DLText.textLabel.copyWith(fontWeight: FontWeight.w400, color: c.textSecondary),
                ),
              ),
              Text(value, style: (strong ? DLText.amountMd : DLText.amountSm).copyWith(color: color ?? c.textPrimary)),
            ],
          ),
        );

    return Scaffold(
      appBar: DLAppBar(
        title: d.shop.name,
        onLeading: () => popOr(context, Routes.shops),
        actions: [DLIconButton(icon: DLIcons.trash, tooltip: t.del, onPressed: () => _delete(d.shop))],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          DLCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: DLSpace.s2, bottom: DLSpace.s4),
                  child: Column(
                    children: [
                      Text(t.nowDue, style: DLText.textLabel.copyWith(color: c.textSecondary)),
                      Text(f.taka(d.balance), style: DLText.amountHero.copyWith(color: c.textPrimary)),
                      DLTag(label: owes ? t.balance : t.settled, tone: owes ? DLTone.warning : DLTone.success),
                    ],
                  ),
                ),
                kv(t.prevBal, f.taka(d.previousBalance)),
                kv(t.newPurch, f.taka(d.purchases, sign: '+'), color: c.warningText),
                kv(t.paid, f.taka(d.paid, sign: '-'), color: c.successText),
                kv(t.nowDue, f.taka(d.balance), strong: true),
              ],
            ),
          ),
          const SizedBox(height: DLSpace.s3),
          Row(
            children: [
              Expanded(
                child: DLButton(
                  label: t.addPurchase,
                  icon: DLIcons.bag,
                  variant: DLButtonVariant.secondary,
                  onPressed: () => showDLSheet<void>(context, title: t.addPurchase, builder: (_) => _PurchaseSheet(shopId: d.shop.id)),
                ),
              ),
              const SizedBox(width: DLSpace.s2),
              Expanded(
                child: DLButton(
                  label: t.payment,
                  icon: DLIcons.cash,
                  onPressed: owes
                      ? () => showDLSheet<void>(
                            context,
                            title: t.makePayment,
                            subtitle: '${t.nowDue}: ${f.taka(d.balance)}',
                            builder: (_) => _PaymentSheet(shopId: d.shop.id),
                          )
                      : null,
                ),
              ),
            ],
          ),
          if (owes) ...[
            const SizedBox(height: DLSpace.s2),
            DLButton(label: t.settleAll, icon: DLIcons.checkCircle, variant: DLButtonVariant.tonal, size: DLButtonSize.md, onPressed: () => _settle(d)),
          ],
          DLSectionTitle(t.history),
          DLSegmentedTabs<_EntryTab>(
            value: _tab,
            options: [(_EntryTab.all, t.all), (_EntryTab.buy, t.purchase), (_EntryTab.pay, t.payment)],
            onChanged: (v) => setState(() => _tab = v),
          ),
          const SizedBox(height: DLSpace.s3),
          if (entries.isEmpty)
            DLCard(
              padding: const EdgeInsets.symmetric(horizontal: DLSpace.s4, vertical: DLSpace.s10),
              child: Text(t.noHist, textAlign: TextAlign.center, style: DLText.textH3.copyWith(color: c.textPrimary)),
            )
          else
            DLList(
              children: [
                for (final line in entries)
                  Builder(builder: (context) {
                    final e = line.entry;
                    final buy = e.type == ShopEntryType.buy;
                    return DLListRow(
                      leading: DLIconChip(icon: buy ? DLIcons.bag : DLIcons.checkCircle, tone: buy ? DLTone.warning : DLTone.success),
                      title: buy ? (e.item.isNotEmpty ? e.item : t.purchase) : (line.settles ? t.fullPaid : t.partial),
                      subtitle: '${buy ? t.purchase : t.payment} · ${f.dateMedium(e.date)}',
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            f.taka(e.amount, sign: buy ? '+' : '-'),
                            style: DLText.amountMd.copyWith(color: buy ? c.warningText : c.successText),
                          ),
                          Text('${t.balance} ${f.taka(line.runningBalance)}', style: DLText.textCaption.copyWith(color: c.textSecondary)),
                        ],
                      ),
                    );
                  }),
              ],
            ),
        ],
      ),
    );
  }
}

/// Credit purchase sheet: raises the balance; not an expense.
class _PurchaseSheet extends ConsumerStatefulWidget {
  const _PurchaseSheet({required this.shopId});

  final String shopId;

  @override
  ConsumerState<_PurchaseSheet> createState() => _PurchaseSheetState();
}

class _PurchaseSheetState extends ConsumerState<_PurchaseSheet> {
  final _amount = TextEditingController();
  final _item = TextEditingController();
  late DateTime _date = dateOnly(ref.read(clockProvider)());
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _item.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final amount = DLFormat.parseAmount(_amount.text)?.round() ?? 0;
    if (amount <= 0) {
      setState(() => _error = t.errAmount);
      DLToast.show(context, t.errForm, error: true);
      return;
    }
    await ref.read(shopDaoProvider).addPurchase(shopId: widget.shopId, amount: amount, date: _date, item: _item.text.trim());
    if (!mounted) return;
    DLToast.show(context, t.purchaseSaved);
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
          controller: _amount,
          label: t.amount,
          hint: f.count(0),
          amount: true,
          autofocus: true,
          error: _error,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        DLTextField(controller: _item, label: t.item, hint: t.phItem),
        DLPickerField(
          label: t.date,
          value: f.dateMedium(_date),
          icon: DLIcons.calendar,
          onTap: () async {
            final d = await pickDate(context, _date);
            if (d != null && mounted) setState(() => _date = d);
          },
        ),
        _SheetButtons(onSave: _save),
      ],
    );
  }
}

/// Payment sheet (screenshot 26): quick amounts, method; paying more than is
/// owed is blocked. Records an expense in category "shop credit payment".
class _PaymentSheet extends ConsumerStatefulWidget {
  const _PaymentSheet({required this.shopId});

  final String shopId;

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  final _amount = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save(ShopDetail d) async {
    final t = AppLocalizations.of(context);
    final amount = DLFormat.parseAmount(_amount.text)?.round() ?? 0;
    String? error = amount <= 0 ? t.errAmount : (amount > d.balance ? t.errPayOver : null);
    if (error == null) {
      try {
        await ref.read(shopDaoProvider).pay(
              shopId: d.shop.id,
              amount: amount,
              date: dateOnly(ref.read(clockProvider)()),
              method: _method,
              title: t.payTo(d.shop.name),
            );
      } on ShopOverpayException {
        error = t.errPayOver;
      }
    }
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      DLToast.show(context, t.errForm, error: true);
      return;
    }
    DLToast.show(context, t.paymentSaved);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final f = ref.watch(formatProvider);
    final d = ref.watch(shopDetailProvider(widget.shopId)).value;
    if (d == null) return const SizedBox.shrink();
    final bal = d.balance;
    // The prototype's quick picks: up to ৳500, half, everything.
    final quick = <int>{for (final v in [if (bal < 500) bal else 500, (bal / 2).round(), bal]) if (v > 0) v};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DLTextField(
          controller: _amount,
          label: t.amount,
          hint: f.count(0),
          amount: true,
          error: _error,
          bottomGap: DLSpace.s2,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        Wrap(
          spacing: DLSpace.s2,
          runSpacing: 0,
          children: [
            for (final v in quick)
              DLChip(
                label: '${v == bal ? '${t.fullPaid} ' : ''}${f.taka(v)}',
                onTap: () {
                  _amount.text = '$v';
                  if (_error != null) setState(() => _error = null);
                },
              ),
          ],
        ),
        const SizedBox(height: DLSpace.s3),
        DLField(
          label: t.method,
          child: Wrap(
            spacing: DLSpace.s2,
            runSpacing: 0,
            children: [
              for (final m in PaymentMethod.values)
                DLChip(label: paymentLabel(t, m), selected: _method == m, onTap: () => setState(() => _method = m)),
            ],
          ),
        ),
        _SheetButtons(onSave: () => _save(d)),
      ],
    );
  }
}

/// Cancel · Save at the foot of a sheet.
class _SheetButtons extends StatelessWidget {
  const _SheetButtons({required this.onSave});

  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(child: DLButton(label: t.cancel, variant: DLButtonVariant.secondary, onPressed: () => Navigator.of(context).pop())),
        const SizedBox(width: DLSpace.s2),
        Expanded(child: DLButton(label: t.save, onPressed: onSave)),
      ],
    );
  }
}
