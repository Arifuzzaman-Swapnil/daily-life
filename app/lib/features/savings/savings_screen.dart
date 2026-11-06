import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/daos/savings_dao.dart';
import '../../core/db/db_providers.dart';
import '../../core/format/dl_format.dart';
import '../../core/format/dl_format_more.dart';
import '../../core/format/format_provider.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../finance/date_pickers.dart';
import '../finance/money_providers.dart';

/// Savings (prototype `savings`, screenshots 21–23): total, this year's
/// deposits and withdrawals, 6-month growth, goals and history. Deposits are
/// set aside, not spent.
class SavingsScreen extends ConsumerStatefulWidget {
  const SavingsScreen({super.key});

  @override
  ConsumerState<SavingsScreen> createState() => _SavingsScreenState();
}

enum _SavTab { goals, history }

class _SavingsScreenState extends ConsumerState<SavingsScreen> {
  _SavTab _tab = _SavTab.goals;

  void _move(SavingsDirection type) {
    final t = AppLocalizations.of(context);
    showDLSheet<void>(context, title: type == SavingsDirection.deposit ? t.deposit : t.withdraw, builder: (_) => _MoveSheet(type: type));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final total = ref.watch(savingsTotalProvider).value ?? 0;
    final flows = ref.watch(savingsFlowsProvider).value;
    final growth = ref.watch(savingsGrowthProvider).value ?? const [];
    final goals = ref.watch(savingsGoalsProvider).value ?? const <SavingsGoalProgress>[];
    final entries = ref.watch(savingsEntriesProvider).value ?? const <SavingsEntry>[];

    Widget heroTile(String label, String amount) => DLHeroTile(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: DLText.textCaption.copyWith(color: c.brandMuted)),
              Text(amount, style: DLText.amountSm.copyWith(color: c.onBrand)),
            ],
          ),
        );

    return Scaffold(
      appBar: DLAppBar(title: t.savings, onLeading: () => popOr(context, Routes.finance)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          DLHero(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.totalSavings, style: DLText.textLabel.copyWith(color: c.brandMuted)),
                const SizedBox(height: DLSpace.s1),
                Text(f.taka(total), style: DLText.amountHero.copyWith(color: c.onBrand)),
                const SizedBox(height: DLSpace.s4),
                Row(
                  children: [
                    Expanded(child: heroTile(t.contributions, f.taka(flows?.deposits ?? 0, sign: '+'))),
                    const SizedBox(width: DLSpace.s3),
                    Expanded(child: heroTile(t.withdrawals, f.taka(flows?.withdrawals ?? 0, sign: '-'))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: DLSpace.s3),
          Row(
            children: [
              Expanded(child: DLButton(label: t.deposit, icon: DLIcons.plus, onPressed: () => _move(SavingsDirection.deposit))),
              const SizedBox(width: DLSpace.s2),
              Expanded(
                child: DLButton(
                  label: t.withdraw,
                  icon: DLIcons.minus,
                  variant: DLButtonVariant.secondary,
                  onPressed: () => _move(SavingsDirection.withdrawal),
                ),
              ),
            ],
          ),
          const SizedBox(height: DLSpace.s2),
          Text(t.savNote, style: DLText.textBodySm.copyWith(color: c.textSecondary)),
          DLSectionTitle(t.growth),
          DLCard(
            child: DLBarChart(
              height: 130,
              barAreaHeight: 90,
              colors: [c.chart3],
              groups: [
                for (final (m, balance) in growth)
                  DLBarGroup(
                    label: f.monthShort(m),
                    values: [balance.toDouble()],
                    valueLabel: f.takaCompact(balance),
                    semanticLabel: '${f.monthYear(m)}: ${f.taka(balance)}',
                  ),
              ],
            ),
          ),
          const SizedBox(height: DLSpace.s6),
          DLSegmentedTabs<_SavTab>(
            value: _tab,
            options: [(_SavTab.goals, t.goals), (_SavTab.history, t.savHistory)],
            onChanged: (v) => setState(() => _tab = v),
          ),
          const SizedBox(height: DLSpace.s3),
          if (_tab == _SavTab.goals) ...[
            if (goals.isEmpty) DLEmptyState(inCard: true, icon: DLIcons.target, title: t.noGoalSav),
            for (final (i, g) in goals.indexed) ...[
              if (i > 0) const SizedBox(height: DLSpace.s3),
              _GoalCard(goal: g),
            ],
            const SizedBox(height: DLSpace.s3),
            DLAddButton(
              label: t.addGoal,
              onPressed: () => showDLSheet<void>(context, title: t.addGoal, builder: (_) => const _GoalSheet()),
            ),
          ] else if (entries.isEmpty)
            DLEmptyState(
              inCard: true,
              icon: DLIcons.piggy,
              title: t.noSav,
              body: t.noSavSub,
              actionLabel: t.deposit,
              onAction: () => _move(SavingsDirection.deposit),
            )
          else
            DLList(children: [for (final e in entries) _EntryRow(entry: e, goals: goals)]),
        ],
      ),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.goal});

  final SavingsGoalProgress goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final p = goal.percent;
    return DLCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(goal.goal.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: DLText.textH3.copyWith(color: c.textPrimary)),
              ),
              const SizedBox(width: DLSpace.s2),
              DLTag(label: f.percent(p)),
            ],
          ),
          const SizedBox(height: DLSpace.s2),
          DLProgressBar(value: p / 100, semanticLabel: goal.goal.name, semanticValue: f.percent(p)),
          const SizedBox(height: DLSpace.s2),
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: f.taka(goal.saved),
                    children: [
                      TextSpan(text: ' / ${f.taka(goal.goal.target)}', style: TextStyle(fontWeight: FontWeight.w400, color: c.textSecondary)),
                    ],
                  ),
                  style: DLText.amountSm.copyWith(color: c.textPrimary),
                ),
              ),
              Text(f.dateMedium(goal.goal.targetDate), style: DLText.textBodySm.copyWith(color: c.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends ConsumerWidget {
  const _EntryRow({required this.entry, required this.goals});

  final SavingsEntry entry;
  final List<SavingsGoalProgress> goals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final deposit = entry.type == SavingsDirection.deposit;
    final goal = goals.where((g) => g.goal.id == entry.goalId).firstOrNull;
    return DLListRow(
      leading: DLIconChip(icon: deposit ? DLIcons.income : DLIcons.expense, tone: deposit ? DLTone.success : DLTone.neutral),
      title: entry.note.isNotEmpty ? entry.note : (deposit ? t.deposit : t.withdraw),
      subtitle: [f.dateMedium(entry.date), if (goal != null) goal.goal.name].join(' · '),
      trailing: Text(
        f.taka(entry.amount, sign: deposit ? '+' : '-'),
        style: DLText.amountMd.copyWith(color: deposit ? c.successText : c.dangerText),
      ),
    );
  }
}

/// Deposit / withdraw sheet (screenshot 23). A withdrawal can't exceed the total.
class _MoveSheet extends ConsumerStatefulWidget {
  const _MoveSheet({required this.type});

  final SavingsDirection type;

  @override
  ConsumerState<_MoveSheet> createState() => _MoveSheetState();
}

class _MoveSheetState extends ConsumerState<_MoveSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _goalId;
  bool _goalPicked = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save(List<SavingsGoalProgress> goals) async {
    final t = AppLocalizations.of(context);
    final amount = DLFormat.parseAmount(_amount.text)?.round() ?? 0;
    final withdrawal = widget.type == SavingsDirection.withdrawal;
    String? error;
    if (amount <= 0) {
      error = t.errAmount;
    } else if (withdrawal && amount > (ref.read(savingsTotalProvider).value ?? amount)) {
      error = t.errWithdraw;
    }
    if (error == null) {
      try {
        await ref.read(savingsDaoProvider).addEntry(
              type: widget.type,
              amount: amount,
              date: dateOnly(ref.read(clockProvider)()),
              note: _note.text.trim(),
              goalId: _goalPicked ? _goalId : goals.firstOrNull?.goal.id,
            );
      } on SavingsOverdrawException {
        error = t.errWithdraw;
      }
    }
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      DLToast.show(context, t.errForm, error: true);
      return;
    }
    DLToast.show(context, t.savSaved);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final f = ref.watch(formatProvider);
    final goals = ref.watch(savingsGoalsProvider).value ?? const <SavingsGoalProgress>[];
    // Like the prototype, the first goal is chosen until another is picked.
    final selected = _goalPicked ? _goalId : goals.firstOrNull?.goal.id;
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
        if (goals.isNotEmpty)
          DLField(
            label: t.toGoal,
            child: Wrap(
              spacing: DLSpace.s2,
              runSpacing: 0,
              children: [
                for (final g in goals)
                  DLChip(
                    label: g.goal.name,
                    selected: selected == g.goal.id,
                    onTap: () => setState(() {
                      _goalPicked = true;
                      _goalId = g.goal.id;
                    }),
                  ),
              ],
            ),
          ),
        DLTextField(controller: _note, label: t.note, hint: t.phNote),
        _SheetButtons(onSave: () => _save(goals)),
      ],
    );
  }
}

/// New savings goal sheet.
class _GoalSheet extends ConsumerStatefulWidget {
  const _GoalSheet();

  @override
  ConsumerState<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends ConsumerState<_GoalSheet> {
  final _name = TextEditingController();
  final _target = TextEditingController();
  // The prototype's default target date: 30 June of next year.
  late DateTime _date = DateTime(ref.read(clockProvider)().year + 1, 6, 30);
  Map<String, String> _errors = const {};

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  void _clear(String key) {
    if (_errors.containsKey(key)) setState(() => _errors = {..._errors}..remove(key));
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final name = _name.text.trim();
    final target = DLFormat.parseAmount(_target.text)?.round() ?? 0;
    final errors = {
      if (name.isEmpty) 'title': t.errTitle,
      if (target <= 0) 'target': t.errAmount,
    };
    setState(() => _errors = errors);
    if (errors.isNotEmpty) {
      DLToast.show(context, t.errForm, error: true);
      return;
    }
    await ref.read(savingsDaoProvider).addGoal(name: name, target: target, targetDate: _date);
    if (!mounted) return;
    DLToast.show(context, t.goalSaved);
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
          label: t.goalName,
          hint: t.phGoal,
          error: _errors['title'],
          autofocus: true,
          onChanged: (_) => _clear('title'),
        ),
        DLTextField(
          controller: _target,
          label: t.target,
          keyboardType: TextInputType.number,
          error: _errors['target'],
          onChanged: (_) => _clear('target'),
        ),
        DLPickerField(
          label: t.targetDate,
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
