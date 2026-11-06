import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';
import '../../core/format/format_provider.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../calendar/calendar_ui.dart';
import '../work/work_ui.dart';
import 'reminders_providers.dart';
import 'reminders_ui.dart';

/// New / edit reminder (prototype `addRem`, screenshot 53): title, details,
/// when, priority, category, repeat (custom = chosen weekdays) and on/off.
class ReminderFormScreen extends ConsumerStatefulWidget {
  const ReminderFormScreen({super.key, this.landOnList = false}) : editId = null;

  const ReminderFormScreen.edit({super.key, required String id})
      : editId = id,
        landOnList = false;

  final String? editId;

  /// Opened from outside Reminders (Home): saving shows the Reminders list.
  final bool landOnList;

  @override
  ConsumerState<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends ConsumerState<ReminderFormScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  late DateTime _date = dateOnly(ref.read(clockProvider)());
  String _time = '18:00';
  PriorityLevel _priority = PriorityLevel.medium;
  ReminderCategory _category = ReminderCategory.personal;
  RepeatRule _repeat = RepeatRule.once;
  Set<int> _days = {};
  bool _enabled = true;
  Reminder? _original;
  late bool _loading = widget.editId != null;
  Map<String, String> _errors = const {};

  @override
  void initState() {
    super.initState();
    if (widget.editId != null) _load(widget.editId!);
  }

  Future<void> _load(String id) async {
    final r = await ref.read(remindersDaoProvider).reminderById(id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r == null) return;
      _original = r;
      _title.text = r.title;
      _desc.text = r.description;
      _date = r.date;
      _time = r.time;
      _priority = r.priority;
      _category = r.category;
      _repeat = r.repeat;
      _days = {...r.customDays};
      _enabled = r.enabled;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _clearError(String key) {
    if (_errors.containsKey(key)) setState(() => _errors = {..._errors}..remove(key));
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final title = _title.text.trim();
    final errors = {if (title.isEmpty) 'title': t.errTitle};
    setState(() => _errors = errors);
    if (errors.isNotEmpty) {
      DLToast.show(context, t.errForm, error: true);
      return;
    }
    final dao = ref.read(remindersDaoProvider);
    final original = _original;
    final days = _repeat == RepeatRule.custom ? _days : <int>{};
    if (original != null) {
      await dao.updateReminder(original.copyWith(
        title: title,
        description: _desc.text.trim(),
        date: _date,
        time: _time,
        priority: _priority,
        category: _category,
        repeat: _repeat,
        customDays: days,
        enabled: _enabled,
      ));
    } else {
      await dao.addReminder(RemindersCompanion.insert(
        title: title,
        description: Value(_desc.text.trim()),
        date: _date,
        time: _time,
        priority: _priority,
        category: _category,
        repeat: _repeat,
        customDays: Value(days),
        enabled: Value(_enabled),
      ));
    }
    if (!mounted) return;
    // The list opens on the tab the reminder now belongs to.
    final today = dateOnly(ref.read(clockProvider)());
    ref.read(remTabProvider.notifier).set(_date.isAfter(today) ? RemTab.upcoming : RemTab.today);
    DLToast.show(context, t.remSaved);
    if (widget.landOnList) {
      context.pushReplacement(Routes.reminders);
    } else {
      popOr(context, Routes.reminders);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final appBar = DLAppBar(
      title: widget.editId != null ? t.editRem : t.newRem,
      leading: DLAppBarLeading.close,
      onLeading: () => popOr(context, Routes.reminders),
    );
    if (_loading) return Scaffold(appBar: appBar, body: const SizedBox.shrink());

    Widget chips<T>(List<(T, String, IconData?)> options, T value, ValueChanged<T> onPick) => Wrap(
          spacing: DLSpace.s2,
          runSpacing: 0,
          children: [
            for (final (v, label, icon) in options) DLChip(label: label, icon: icon, selected: v == value, onTap: () => onPick(v)),
          ],
        );

    return Scaffold(
      appBar: appBar,
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          DLTextField(
            controller: _title,
            label: t.title,
            hint: t.phRem,
            error: _errors['title'],
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearError('title'),
          ),
          DLTextField(controller: _desc, label: t.desc, hint: t.phDesc, multiline: true),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DLPickerField(
                  label: t.date,
                  value: f.dateMedium(_date),
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
          Padding(
            padding: const EdgeInsets.only(bottom: DLSpace.s3),
            child: Text('${f.dateLong(_date)} · ${f.time(_time)}', style: DLText.textBodySm.copyWith(color: c.textSecondary)),
          ),
          DLField(
            label: t.priority,
            child: chips([for (final p in PriorityLevel.values) (p, priorityLabel(t, p), null)], _priority, (p) => setState(() => _priority = p)),
          ),
          DLField(
            label: t.category,
            child: chips(
              [for (final cat in ReminderCategory.values) (cat, reminderCategoryLabel(t, cat), reminderIcon(cat).$1)],
              _category,
              (cat) => setState(() => _category = cat),
            ),
          ),
          DLField(
            label: t.repeat,
            child: chips([for (final r in RepeatRule.values) (r, repeatLabel(t, r), null)], _repeat, (r) => setState(() => _repeat = r)),
          ),
          if (_repeat == RepeatRule.custom)
            DLField(
              label: t.customDays,
              child: Row(
                children: [
                  for (final (i, label) in f.weekHeaders().indexed) ...[
                    if (i > 0) const SizedBox(width: DLSpace.s1),
                    Expanded(
                      child: _DayToggle(
                        label: label,
                        selected: _days.contains(i),
                        onTap: () {
                          setState(() => _days = _days.contains(i) ? ({..._days}..remove(i)) : {..._days, i});
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: DLSpace.s4),
            child: DLCard(
              outlined: true,
              padding: const EdgeInsets.symmetric(horizontal: DLSpace.s4, vertical: DLSpace.s1),
              child: Row(
                children: [
                  Expanded(child: Text(t.enabledL, style: DLText.textLabel.copyWith(color: c.textPrimary))),
                  DLSwitch(value: _enabled, semanticLabel: t.enabledL, onChanged: (v) => setState(() => _enabled = v)),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: DLButton(label: t.cancel, variant: DLButtonVariant.secondary, onPressed: () => popOr(context, Routes.reminders)),
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

/// A weekday of a custom repeat (prototype: a 44-tall primary / secondary
/// button per day, Saturday first).
class _DayToggle extends StatelessWidget {
  const _DayToggle({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    const shape = BorderRadius.all(Radius.circular(DLRadius.md));
    return DLPressable(
      onTap: onTap,
      selected: selected,
      borderRadius: shape,
      decoration: BoxDecoration(
        color: selected ? c.actionPrimary : c.surface,
        borderRadius: shape,
        border: Border.all(color: selected ? c.actionPrimary : c.borderStrong),
      ),
      child: SizedBox(
        height: DLSize.controlMd,
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
            style: DLText.amountSm.copyWith(color: selected ? c.onActionPrimary : c.accentText),
          ),
        ),
      ),
    );
  }
}
