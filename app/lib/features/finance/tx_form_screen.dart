import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';
import '../../core/format/dl_format.dart';
import '../../core/format/dl_format_more.dart';
import '../../core/format/format_provider.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import 'categories.dart';
import 'category_sheet.dart';
import 'money_providers.dart';

/// Add income / add expense / edit a transaction (prototype `addTx`,
/// screenshots 15 and 16). Validates amount, title and category before saving;
/// a new one returns to Finance on its type's tab and month.
class TxFormScreen extends ConsumerStatefulWidget {
  const TxFormScreen({super.key, required TxType type})
      : initialType = type,
        editId = null;

  const TxFormScreen.edit({super.key, required String id})
      : editId = id,
        initialType = TxType.expense;

  final TxType initialType;
  final String? editId;

  @override
  ConsumerState<TxFormScreen> createState() => _TxFormScreenState();
}

class _TxFormScreenState extends ConsumerState<TxFormScreen> {
  final _amount = TextEditingController();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _note = TextEditingController();
  late TxType _type = widget.initialType;
  String? _categoryId;
  late DateTime _date = dateOnly(ref.read(clockProvider)());
  String _time = '12:00';
  late PaymentMethod _method = _defaultMethod(_type);
  String? _allocationId;
  Txn? _original;
  late bool _loading = widget.editId != null;
  Map<String, String> _errors = const {};

  static PaymentMethod _defaultMethod(TxType type) => type == TxType.income ? PaymentMethod.bank : PaymentMethod.cash;

  bool get _expense => _type == TxType.expense;

  @override
  void initState() {
    super.initState();
    if (widget.editId != null) _load(widget.editId!);
  }

  Future<void> _load(String id) async {
    final x = await ref.read(financeDaoProvider).transactionById(id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (x == null) return;
      _original = x;
      _type = x.type;
      _amount.text = '${x.amount}';
      _title.text = x.title;
      _desc.text = x.description;
      _note.text = x.note;
      _categoryId = x.categoryId;
      _date = x.date;
      _time = x.time;
      _method = x.paymentMethod;
      _allocationId = x.allocationId;
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    _desc.dispose();
    _note.dispose();
    super.dispose();
  }

  void _clearError(String key) {
    if (_errors.containsKey(key)) setState(() => _errors = {..._errors}..remove(key));
  }

  void _setType(TxType type) => setState(() {
        _type = type;
        _categoryId = null;
        _method = _defaultMethod(type);
        _errors = const {};
      });

  Future<void> _newCategory() async {
    final created = await showNewCategorySheet(context, type: _type);
    if (created == null || !mounted) return;
    setState(() => _categoryId = created.$2);
    _clearError('cat');
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final amount = DLFormat.parseAmount(_amount.text)?.round() ?? 0;
    final title = _title.text.trim();
    final errors = {
      if (amount <= 0) 'amount': t.errAmount,
      if (title.isEmpty) 'title': t.errTitle,
      if (_categoryId == null) 'cat': t.errCat,
    };
    setState(() => _errors = errors);
    if (errors.isNotEmpty) {
      DLToast.show(context, t.errForm, error: true);
      return;
    }
    final dao = ref.read(financeDaoProvider);
    final allocation = _expense ? _allocationId : null;
    final original = _original;
    if (original != null) {
      await dao.updateTransaction(original.copyWith(
        title: title,
        categoryId: _categoryId,
        amount: amount,
        date: _date,
        time: _time,
        paymentMethod: _method,
        description: _desc.text.trim(),
        note: _note.text.trim(),
        allocationId: Value(allocation),
      ));
    } else {
      await dao.addTransaction(TransactionsCompanion.insert(
        type: _type,
        title: title,
        categoryId: _categoryId!,
        amount: amount,
        date: _date,
        time: Value(_time),
        paymentMethod: _method,
        description: Value(_desc.text.trim()),
        note: Value(_note.text.trim()),
        allocationId: Value(allocation),
      ));
    }
    if (!mounted) return;
    // Like the prototype: Finance shows the saved row's month and type.
    ref.read(selectedMonthProvider.notifier).show(_date);
    ref.read(finFilterProvider.notifier).setTab(_expense ? FinTab.expense : FinTab.income);
    DLToast.show(context, original != null ? t.txUpdated : (_expense ? t.expSaved : t.incSaved));
    popOr(context, Routes.finance);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final f = ref.watch(formatProvider);
    final book = ref.watch(categoryBookProvider);
    final allocations = ref.watch(allocationsProvider).value ?? const [];
    final isNew = widget.editId == null;
    final title = !isNew ? t.editTx : (_expense ? t.addExpense : t.addIncome);
    final appBar = DLAppBar(title: title, leading: DLAppBarLeading.close, onLeading: () => popOr(context, Routes.finance));
    if (_loading) return Scaffold(appBar: appBar, body: const SizedBox.shrink());

    final description = DLTextField(
      controller: _desc,
      label: _expense ? t.reason : t.desc,
      hint: t.phDesc,
      multiline: true,
    );

    return Scaffold(
      appBar: appBar,
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          if (isNew) ...[
            DLSegmentedTabs<TxType>(
              value: _type,
              options: [(TxType.income, t.income), (TxType.expense, t.expense)],
              onChanged: _setType,
            ),
            const SizedBox(height: DLSpace.s5),
          ],
          DLTextField(
            controller: _amount,
            label: t.amount,
            hint: f.count(0),
            amount: true,
            error: _errors['amount'],
            onChanged: (_) => _clearError('amount'),
          ),
          DLTextField(
            controller: _title,
            label: _expense ? t.expTitle : t.incName,
            hint: _expense ? t.phExpTitle : t.phIncName,
            error: _errors['title'],
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearError('title'),
          ),
          DLField(
            label: t.category,
            error: _errors['cat'],
            child: Wrap(
              spacing: DLSpace.s2,
              runSpacing: 0,
              children: [
                for (final cat in book.pickable(_type))
                  Builder(builder: (context) {
                    final info = categoryInfo(t, book, _type, cat.id);
                    return DLChip(
                      label: info.label,
                      icon: info.icon,
                      selected: _categoryId == cat.id,
                      onTap: () {
                        setState(() => _categoryId = cat.id);
                        _clearError('cat');
                      },
                    );
                  }),
                DLChip(label: t.newCat, icon: DLIcons.plus, dashed: true, onTap: _newCategory),
              ],
            ),
          ),
          if (_expense) description,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DLPickerField(
                  label: t.date,
                  value: f.dateMedium(_date),
                  helper: f.dateLong(_date),
                  icon: DLIcons.calendar,
                  onTap: () async {
                    final d = await pickDate(context, _date);
                    if (d != null && mounted) setState(() => _date = d);
                  },
                ),
              ),
              const SizedBox(width: DLSpace.s3),
              Expanded(
                child: DLPickerField(
                  label: t.time,
                  value: f.time(_time),
                  icon: DLIcons.clock,
                  onTap: () async {
                    final hm = await pickTime(context, _time);
                    if (hm != null && mounted) setState(() => _time = hm);
                  },
                ),
              ),
            ],
          ),
          DLSelect<PaymentMethod>(
            label: t.method,
            value: _method,
            options: [for (final m in PaymentMethod.values) (m, paymentLabel(t, m))],
            onChanged: (m) => setState(() => _method = m),
          ),
          if (_expense)
            DLSelect<String?>(
              label: t.budgetCat,
              value: allocations.any((a) => a.id == _allocationId) ? _allocationId : null,
              options: [
                (null, t.none),
                for (final a in allocations) (a.id, a.name.isEmpty ? t.catNamePh : a.name),
              ],
              // The first sentence of the allocation note: "Allocation is budget planning".
              helper: t.allocNote.split(RegExp('[।.—]')).first.trim(),
              onChanged: (id) => setState(() => _allocationId = id),
            ),
          if (!_expense) description,
          DLTextField(controller: _note, label: t.optNote, optionalLabel: t.optional, hint: t.phNote),
          const SizedBox(height: DLSpace.s2),
          Row(
            children: [
              Expanded(
                child: DLButton(
                  label: t.cancel,
                  variant: DLButtonVariant.secondary,
                  onPressed: () => popOr(context, Routes.finance),
                ),
              ),
              const SizedBox(width: DLSpace.s2),
              Expanded(child: DLButton(label: t.save, onPressed: _save)),
            ],
          ),
        ],
      ),
    );
  }
}
