import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';

/// "New category" sheet. From a transaction form the [type] is fixed; from the
/// Categories screen ([type] null) it starts with an Expense / Income switch.
/// Resolves to the new category's (type, id), or null when cancelled.
Future<(TxType, String)?> showNewCategorySheet(BuildContext context, {TxType? type}) => showDLSheet<(TxType, String)>(
      context,
      title: AppLocalizations.of(context).newCat,
      builder: (_) => _NewCategorySheet(fixedType: type),
    );

class _NewCategorySheet extends ConsumerStatefulWidget {
  const _NewCategorySheet({this.fixedType});

  final TxType? fixedType;

  @override
  ConsumerState<_NewCategorySheet> createState() => _NewCategorySheetState();
}

class _NewCategorySheetState extends ConsumerState<_NewCategorySheet> {
  final _name = TextEditingController();
  late TxType _type = widget.fixedType ?? TxType.expense;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = t.errTitle);
      return;
    }
    final id = await ref.read(financeDaoProvider).addCategory(_type, name);
    if (!mounted) return;
    DLToast.show(context, t.catAdded);
    Navigator.of(context).pop((_type, id));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.fixedType == null) ...[
          DLSegmentedTabs<TxType>(
            value: _type,
            options: [(TxType.expense, t.expense), (TxType.income, t.income)],
            onChanged: (v) => setState(() => _type = v),
          ),
          const SizedBox(height: DLSpace.s4),
        ],
        DLTextField(
          controller: _name,
          label: t.catName,
          hint: t.phCat,
          error: _error,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _save(),
        ),
        Row(
          children: [
            Expanded(child: DLButton(label: t.cancel, variant: DLButtonVariant.secondary, onPressed: () => Navigator.of(context).pop())),
            const SizedBox(width: DLSpace.s2),
            Expanded(child: DLButton(label: t.add, onPressed: _save)),
          ],
        ),
      ],
    );
  }
}
