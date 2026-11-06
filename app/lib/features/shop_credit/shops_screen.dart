import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';
import '../../core/format/dl_format.dart';
import '../../core/format/dl_format_more.dart';
import '../../core/format/format_provider.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../finance/money_providers.dart';

/// Shop credit (prototype `shops`, screenshot 24): what is owed in total and
/// per shop. Credit purchases aren't expenses; payments are.
class ShopsScreen extends ConsumerWidget {
  const ShopsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final today = dateOnly(ref.watch(clockProvider)());
    final due = ref.watch(shopDueProvider).value;
    final shops = ref.watch(shopsProvider).value;
    void addShop() => showDLSheet<void>(context, title: t.addShop, builder: (_) => const _AddShopSheet());

    return Scaffold(
      appBar: DLAppBar(
        title: t.shopCredit,
        onLeading: () => popOr(context, Routes.finance),
        actions: [DLIconButton(icon: DLIcons.plus, tooltip: t.addShop, onPressed: addShop)],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          DLHero(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.outstanding, style: DLText.textLabel.copyWith(color: c.brandMuted)),
                const SizedBox(height: DLSpace.s1),
                Text(f.taka(due?.total ?? 0), style: DLText.amountHero.copyWith(color: c.onBrand)),
                Text(t.shopsDue(f.count(due?.shops ?? 0)), style: DLText.textBodySm.copyWith(color: c.brandMuted)),
              ],
            ),
          ),
          const SizedBox(height: DLSpace.s3),
          DLNote(t.creditNote, tone: DLTone.warning),
          DLSectionTitle(t.shops),
          if (shops != null && shops.isEmpty)
            DLEmptyState(
              inCard: true,
              icon: DLIcons.store,
              title: t.noShops,
              body: t.noShopsSub,
              actionLabel: t.addShop,
              onAction: addShop,
            )
          else if (shops != null)
            DLList(
              children: [
                for (final s in shops)
                  DLListRow(
                    leading: const DLIconChip(icon: DLIcons.store, tone: DLTone.warning),
                    title: s.shop.name,
                    subtitle: s.lastType == null
                        ? t.noHist
                        : '${s.lastType == ShopEntryType.buy ? t.purchase : t.payment} · ${f.relative(s.lastDate!, today)}',
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(f.taka(s.balance), style: DLText.amountMd.copyWith(color: c.textPrimary)),
                        DLTag(label: s.balance > 0 ? t.balance : t.settled, tone: s.balance > 0 ? DLTone.warning : DLTone.success),
                      ],
                    ),
                    onTap: () => context.push(Routes.shop(s.shop.id)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// New shop with an optional opening balance (recorded as "Previous balance").
class _AddShopSheet extends ConsumerStatefulWidget {
  const _AddShopSheet();

  @override
  ConsumerState<_AddShopSheet> createState() => _AddShopSheetState();
}

class _AddShopSheetState extends ConsumerState<_AddShopSheet> {
  final _name = TextEditingController();
  final _opening = TextEditingController();
  Map<String, String> _errors = const {};

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  void _clear(String key) {
    if (_errors.containsKey(key)) setState(() => _errors = {..._errors}..remove(key));
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final name = _name.text.trim();
    final text = _opening.text.trim();
    final opening = text.isEmpty ? 0 : DLFormat.parseAmount(text)?.round();
    final errors = {
      if (name.isEmpty) 'name': t.errTitle,
      if (opening == null) 'amount': t.errAmount,
    };
    setState(() => _errors = errors);
    if (errors.isNotEmpty) {
      DLToast.show(context, t.errForm, error: true);
      return;
    }
    await ref.read(shopDaoProvider).addShop(
          name,
          openingBalance: opening!,
          date: dateOnly(ref.read(clockProvider)()),
          openingItem: t.prevBal,
        );
    if (!mounted) return;
    DLToast.show(context, t.shopAdded);
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
          label: t.shopName,
          hint: t.phShop,
          error: _errors['name'],
          autofocus: true,
          onChanged: (_) => _clear('name'),
        ),
        DLTextField(
          controller: _opening,
          label: t.openingBal,
          hint: f.count(0),
          keyboardType: TextInputType.number,
          error: _errors['amount'],
          onChanged: (_) => _clear('amount'),
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
