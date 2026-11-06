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
import '../finance/date_pickers.dart';

/// Add salary (prototype `addSalary`, screenshot 19). Saving records the
/// salary, an income transaction (category salary) and the new monthly amount.
class AddSalaryScreen extends ConsumerStatefulWidget {
  const AddSalaryScreen({super.key});

  @override
  ConsumerState<AddSalaryScreen> createState() => _AddSalaryScreenState();
}

class _AddSalaryScreenState extends ConsumerState<AddSalaryScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late final DateTime _today = dateOnly(ref.read(clockProvider)());
  late DateTime _month = DateTime(_today.year, _today.month);
  late DateTime _paid = _today;
  PaymentMethod _method = PaymentMethod.bank;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    // Starts from the current monthly salary, as typed digits (like the prototype).
    ref.read(salaryDaoProvider).settings().then((s) {
      if (mounted && _amount.text.isEmpty && s.monthlyAmount > 0) _amount.text = '${s.monthlyAmount}';
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final f = ref.read(formatProvider);
    final amount = DLFormat.parseAmount(_amount.text)?.round() ?? 0;
    if (amount <= 0) {
      setState(() => _amountError = t.errAmount);
      DLToast.show(context, t.errForm, error: true);
      return;
    }
    await ref.read(salaryDaoProvider).addSalary(
          month: _month,
          paidDate: _paid,
          amount: amount,
          method: _method,
          // "November salary" in the current language.
          title: t.salaryFor(f.monthName(_month)),
          note: _note.text.trim(),
        );
    if (!mounted) return;
    DLToast.show(context, t.salarySaved);
    popOr(context, Routes.salary);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final f = ref.watch(formatProvider);
    final months = [for (var i = 0; i < 6; i++) DateTime(_today.year, _today.month - i)];

    return Scaffold(
      appBar: DLAppBar(title: t.addSalary, leading: DLAppBarLeading.close, onLeading: () => popOr(context, Routes.salary)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          DLTextField(
            controller: _amount,
            label: t.amount,
            hint: f.count(0),
            amount: true,
            error: _amountError,
            onChanged: (_) {
              if (_amountError != null) setState(() => _amountError = null);
            },
          ),
          DLSelect<DateTime>(
            label: t.salaryMonth,
            value: _month,
            options: [for (final m in months) (m, f.monthYear(m))],
            onChanged: (m) => setState(() => _month = m),
          ),
          DLPickerField(
            label: t.payDate,
            value: f.dateMedium(_paid),
            helper: f.dateLong(_paid),
            icon: DLIcons.calendar,
            onTap: () async {
              final d = await pickDate(context, _paid);
              if (d != null && mounted) setState(() => _paid = d);
            },
          ),
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
          DLTextField(controller: _note, label: t.note, optionalLabel: t.optional, hint: t.phNote, multiline: true),
          DLNote(t.salaryNote),
          const SizedBox(height: DLSpace.s4),
          Row(
            children: [
              Expanded(
                child: DLButton(label: t.cancel, variant: DLButtonVariant.secondary, onPressed: () => popOr(context, Routes.salary)),
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
