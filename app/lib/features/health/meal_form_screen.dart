import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';
import '../../core/format/format_provider.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../notifications/notification_planner.dart';
import 'health_screen.dart';

/// Add / edit a meal (prototype `mealForm`, screenshot 60): type, what was
/// eaten (required), when, a note; delete when editing.
class MealFormScreen extends ConsumerStatefulWidget {
  const MealFormScreen({super.key, this.type = MealType.snack}) : editId = null;

  const MealFormScreen.edit({super.key, required String id})
      : editId = id,
        type = MealType.snack;

  final MealType type;
  final String? editId;

  @override
  ConsumerState<MealFormScreen> createState() => _MealFormScreenState();
}

class _MealFormScreenState extends ConsumerState<MealFormScreen> {
  final _desc = TextEditingController();
  final _note = TextEditingController();
  late MealType _type = widget.type;
  late DateTime _date = dateOnly(ref.read(clockProvider)());
  late String _time = mealTimes[widget.type]!;
  Meal? _original;
  late bool _loading = widget.editId != null;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.editId != null) _load(widget.editId!);
  }

  Future<void> _load(String id) async {
    final m = await ref.read(healthDaoProvider).mealById(id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (m == null) return;
      _original = m;
      _desc.text = m.description;
      _note.text = m.note;
      _type = m.type;
      _date = m.date;
      _time = m.time;
    });
  }

  @override
  void dispose() {
    _desc.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final desc = _desc.text.trim();
    if (desc.isEmpty) {
      setState(() => _error = t.errTitle);
      DLToast.show(context, t.errForm, error: true);
      return;
    }
    final dao = ref.read(healthDaoProvider);
    final original = _original;
    if (original != null) {
      await dao.updateMeal(original.copyWith(type: _type, description: desc, date: _date, time: _time, note: _note.text.trim()));
    } else {
      await dao.addMeal(MealsCompanion.insert(
        type: _type,
        date: _date,
        time: _time,
        description: Value(desc),
        note: Value(_note.text.trim()),
      ));
    }
    if (!mounted) return;
    DLToast.show(context, t.mealSaved);
    popOr(context, Routes.health);
  }

  Future<void> _delete(Meal m) async {
    final t = AppLocalizations.of(context);
    final ok = await showDLConfirm(context, title: t.delMealQ, body: m.description);
    if (!ok || !mounted) return;
    await ref.read(healthDaoProvider).deleteMeal(m.id);
    if (!mounted) return;
    DLToast.show(context, t.mealDeleted);
    popOr(context, Routes.health);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final f = ref.watch(formatProvider);
    final original = _original;
    final appBar = DLAppBar(
      title: widget.editId != null ? t.editMeal : t.addMeal,
      leading: DLAppBarLeading.close,
      onLeading: () => popOr(context, Routes.health),
      actions: [
        if (original != null) DLIconButton(icon: DLIcons.trash, tooltip: t.del, onPressed: () => _delete(original)),
      ],
    );
    if (_loading) return Scaffold(appBar: appBar, body: const SizedBox.shrink());

    return Scaffold(
      appBar: appBar,
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          DLField(
            label: t.mealType,
            child: Wrap(
              spacing: DLSpace.s2,
              runSpacing: 0,
              children: [
                for (final m in MealType.values)
                  DLChip(label: mealLabel(t, m), icon: mealIcon(m).$1, selected: m == _type, onTap: () => setState(() => _type = m)),
              ],
            ),
          ),
          DLTextField(
            controller: _desc,
            label: t.mealDesc,
            hint: t.phMeal,
            multiline: true,
            error: _error,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
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
          DLTextField(controller: _note, label: t.note, optionalLabel: t.optional, hint: t.phNote),
          const SizedBox(height: DLSpace.s2),
          Row(
            children: [
              Expanded(
                child: DLButton(label: t.cancel, variant: DLButtonVariant.secondary, onPressed: () => popOr(context, Routes.health)),
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
