import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';
import '../../core/format/dl_format.dart';
import '../../core/format/format_provider.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../finance/money_providers.dart';

/// Salary allocation (prototype `allocation`, screenshot 20). Budget planning,
/// not spending: rows are edited in place and saved as you type; each linked
/// row compares its budget with this month's real spending. Save drops empty rows.
class AllocationScreen extends ConsumerStatefulWidget {
  const AllocationScreen({super.key});

  @override
  ConsumerState<AllocationScreen> createState() => _AllocationScreenState();
}

class _AllocationScreenState extends ConsumerState<AllocationScreen> {
  final _names = <String, TextEditingController>{};
  final _amounts = <String, TextEditingController>{};
  String? _focusId;

  /// Prototype `.c1`…`.c5`, cycling down the rows.
  static List<Color> _palette(DLColors c) => [c.chart1, c.chart2, c.chart3, c.chart4, c.borderStrong];

  @override
  void dispose() {
    for (final x in [..._names.values, ..._amounts.values]) {
      x.dispose();
    }
    super.dispose();
  }

  /// One pair of controllers per row, created once so typing is never
  /// overwritten by the database echo; removed rows' controllers are disposed
  /// after the frame that drops their fields.
  void _syncControllers(List<Allocation> rows) {
    for (final a in rows) {
      _names.putIfAbsent(a.id, () => TextEditingController(text: a.name));
      _amounts.putIfAbsent(a.id, () => TextEditingController(text: a.amount == 0 ? '' : '${a.amount}'));
    }
    final ids = {for (final a in rows) a.id};
    final gone = [
      for (final id in _names.keys.toList())
        if (!ids.contains(id)) ...[_names.remove(id)!, _amounts.remove(id)!],
    ];
    if (gone.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final x in gone) {
          x.dispose();
        }
      });
    }
  }

  Future<void> _remove(Allocation a) async {
    final t = AppLocalizations.of(context);
    final name = _names[a.id]?.text.trim() ?? '';
    final amount = DLFormat.parseAmount(_amounts[a.id]?.text ?? '') ?? 0;
    if (name.isNotEmpty || amount > 0) {
      final ok = await showDLConfirm(context, title: '${t.removeRow}?', body: name.isEmpty ? null : name);
      if (!ok || !mounted) return;
    }
    await ref.read(salaryDaoProvider).deleteAllocation(a.id);
  }

  Future<void> _addRow() async {
    final id = await ref.read(salaryDaoProvider).addAllocation();
    if (mounted) setState(() => _focusId = id);
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    await ref.read(salaryDaoProvider).removeEmptyAllocations();
    if (mounted) DLToast.show(context, t.allocSaved);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final salary = ref.watch(salaryConfigProvider).value?.monthlyAmount ?? 0;
    final rows = ref.watch(allocationsProvider).value ?? const <Allocation>[];
    final spending = ref.watch(allocationSpendingProvider).value ?? const <String, int>{};
    _syncControllers(rows);

    final palette = _palette(c);
    final total = rows.fold<int>(0, (s, a) => s + a.amount);
    final unallocated = salary - total;
    String pctOf(num part) => f.percent(salary > 0 ? part / salary * 100 : 0);

    return Scaffold(
      appBar: DLAppBar(title: t.allocation, onLeading: () => popOr(context, Routes.salary)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          DLCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(t.monthlySalary, style: DLText.textLabel.copyWith(color: c.textSecondary))),
                    Text(f.taka(salary), style: DLText.amountLg.copyWith(color: c.textPrimary)),
                  ],
                ),
                const SizedBox(height: DLSpace.s3),
                Semantics(
                  label: '${t.allocated} ${pctOf(total)}',
                  child: _SplitBar(
                    parts: [
                      for (final (i, a) in rows.indexed)
                        if (a.amount > 0) (a.amount, palette[i % palette.length]),
                    ],
                    whole: math.max(salary, total),
                  ),
                ),
                const SizedBox(height: DLSpace.s3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.allocated, style: DLText.textBodySm.copyWith(color: c.textSecondary)),
                          Text(f.taka(total), style: DLText.amountMd.copyWith(color: c.textPrimary)),
                          Text(pctOf(total), style: DLText.textCaption.copyWith(color: c.textSecondary)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(t.unallocated, style: DLText.textBodySm.copyWith(color: c.textSecondary)),
                        Text(
                          f.taka(unallocated.abs()),
                          style: DLText.amountMd.copyWith(color: unallocated < 0 ? c.dangerText : c.successText),
                        ),
                        Text(pctOf(math.max(0, unallocated)), style: DLText.textCaption.copyWith(color: c.textSecondary)),
                      ],
                    ),
                  ],
                ),
                if (unallocated < 0) ...[
                  const SizedBox(height: DLSpace.s3),
                  _StatusLine(tone: DLTone.danger, icon: DLIcons.alert, text: t.overAlloc(f.taka(-unallocated))),
                ],
                if (unallocated == 0 && salary > 0) ...[
                  const SizedBox(height: DLSpace.s3),
                  _StatusLine(tone: DLTone.success, icon: DLIcons.checkCircle, text: t.fullyAlloc),
                ],
              ],
            ),
          ),
          const SizedBox(height: DLSpace.s3),
          DLNote(t.allocNote),
          for (final (i, a) in rows.indexed) ...[
            SizedBox(height: i == 0 ? DLSpace.s4 : DLSpace.s3),
            _AllocationRow(
              key: ValueKey(a.id),
              allocation: a,
              color: palette[i % palette.length],
              name: _names[a.id]!,
              amount: _amounts[a.id]!,
              percent: pctOf(a.amount),
              spent: spending[a.id] ?? 0,
              autofocus: a.id == _focusId,
              onRemove: () => _remove(a),
            ),
          ],
          const SizedBox(height: DLSpace.s3),
          DLAddButton(label: t.addAllocCat, onPressed: _addRow),
          const SizedBox(height: DLSpace.s4),
          DLButton(label: t.save, onPressed: _save),
        ],
      ),
    );
  }
}

/// The allocated share of the salary, one coloured segment per row, 2 apart.
class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.parts, required this.whole});

  final List<(int, Color)> parts;
  final int whole;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(DLRadius.pill)),
      child: Container(
        height: 12,
        color: context.dl.surfaceSunken,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final gaps = math.max(0, parts.length - 1) * 2.0;
            final room = math.max(0.0, constraints.maxWidth - gaps);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, (amount, color)) in parts.indexed) ...[
                  if (i > 0) const SizedBox(width: 2),
                  SizedBox(width: whole > 0 ? room * math.min(1, amount / whole) : 0.0, child: ColoredBox(color: color)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Over-allocated warning / fully-allocated note under the summary.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.tone, required this.icon, required this.text});

  final DLTone tone;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: DLSpace.s3, vertical: DLSpace.s2),
        decoration: BoxDecoration(color: tone.soft(c), borderRadius: const BorderRadius.all(Radius.circular(DLRadius.sm))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: tone.text(c)),
            const SizedBox(width: DLSpace.s2),
            Flexible(child: Text(text, style: DLText.textBodySm.copyWith(color: tone.text(c)))),
          ],
        ),
      ),
    );
  }
}

/// One budget row: colour dot, editable name, share of salary, remove, the
/// budget amount and (when linked to spending) spent vs left.
class _AllocationRow extends ConsumerWidget {
  const _AllocationRow({
    super.key,
    required this.allocation,
    required this.color,
    required this.name,
    required this.amount,
    required this.percent,
    required this.spent,
    required this.autofocus,
    required this.onRemove,
  });

  final Allocation allocation;
  final Color color;
  final TextEditingController name;
  final TextEditingController amount;
  final String percent;
  final int spent;
  final bool autofocus;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final dao = ref.read(salaryDaoProvider);
    final budget = allocation.amount;
    final left = budget - spent;
    final used = budget > 0 ? spent / budget * 100 : 0.0;
    final nameStyle = DLText.textBody.copyWith(fontWeight: FontWeight.w600, color: c.textPrimary);

    return DLCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DLDot(color: color, size: 12),
              const SizedBox(width: DLSpace.s2),
              Expanded(
                child: Semantics(
                  label: t.catName,
                  textField: true,
                  child: TextField(
                    controller: name,
                    autofocus: autofocus,
                    style: nameStyle,
                    cursorColor: c.accent,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration.collapsed(hintText: t.catNamePh, hintStyle: nameStyle.copyWith(color: c.textSecondary)),
                    onChanged: (v) => dao.updateAllocation(allocation.id, name: v),
                  ),
                ),
              ),
              const SizedBox(width: DLSpace.s2),
              DLTag(label: percent, tone: DLTone.neutral),
              DLIconButton(icon: DLIcons.trash, tooltip: t.removeRow, size: 40, iconSize: 20, onPressed: onRemove),
            ],
          ),
          const SizedBox(height: DLSpace.s3),
          Semantics(
            label: '${allocation.name} ${t.budget}',
            child: DLTextField(
              controller: amount,
              prefixText: '৳ ',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9০-৯]'))],
              bottomGap: 0,
              onChanged: (v) => dao.updateAllocation(allocation.id, amount: DLFormat.parseAmount(v)?.round() ?? 0),
            ),
          ),
          if (allocation.linkedCategoryId != null) ...[
            const SizedBox(height: DLSpace.s3),
            DLProgressBar(
              value: used / 100,
              height: 6,
              tone: used > 100 ? DLTone.danger : (used > 85 ? DLTone.warning : DLTone.accent),
            ),
            const SizedBox(height: DLSpace.s1),
            Row(
              children: [
                Expanded(child: Text('${t.spent} ${f.taka(spent)}', style: DLText.textBodySm.copyWith(color: c.textSecondary))),
                Text(
                  left >= 0 ? '${t.left} ${f.taka(left)}' : t.overBy(f.taka(-left)),
                  style: DLText.amountSm.copyWith(color: left >= 0 ? c.successText : c.dangerText),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
