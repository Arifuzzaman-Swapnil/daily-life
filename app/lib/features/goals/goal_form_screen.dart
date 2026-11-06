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
import 'goals_providers.dart';
import 'goals_screen.dart';

/// New / edit goal (prototype `goalForm`, screenshot 65): title (required),
/// category, description, target date and, for a new goal, milestones one per
/// line. A new goal opens on its details.
class GoalFormScreen extends ConsumerStatefulWidget {
  const GoalFormScreen({super.key}) : editId = null;

  const GoalFormScreen.edit({super.key, required String id}) : editId = id;

  final String? editId;

  @override
  ConsumerState<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends ConsumerState<GoalFormScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _milestones = TextEditingController();
  GoalCategory _category = GoalCategory.personal;

  /// New goals aim for the end of the year (the prototype's 31 December).
  late DateTime _date = DateTime(ref.read(clockProvider)().year, 12, 31);
  Goal? _original;
  late bool _loading = widget.editId != null;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.editId != null) _load(widget.editId!);
  }

  Future<void> _load(String id) async {
    final g = await ref.read(goalsDaoProvider).goalById(id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (g == null) return;
      _original = g;
      _title.text = g.title;
      _desc.text = g.description;
      _category = g.category;
      _date = g.targetDate;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _milestones.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = t.errTitle);
      DLToast.show(context, t.errForm, error: true);
      return;
    }
    final dao = ref.read(goalsDaoProvider);
    final original = _original;
    if (original != null) {
      await dao.updateGoal(original.copyWith(title: title, category: _category, description: _desc.text.trim(), targetDate: _date));
      if (!mounted) return;
      DLToast.show(context, t.goalSaved);
      popOr(context, Routes.goals);
      return;
    }
    final id = await dao.addGoal(
      title: title,
      category: _category,
      targetDate: _date,
      description: _desc.text.trim(),
      milestoneTitles: [for (final line in _milestones.text.split('\n')) if (line.trim().isNotEmpty) line.trim()],
    );
    if (!mounted) return;
    ref.read(goalFilterProvider.notifier).setAchieved(false);
    DLToast.show(context, t.goalSaved);
    context.pushReplacement(Routes.goal(id));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final f = ref.watch(formatProvider);
    final appBar = DLAppBar(
      title: widget.editId != null ? t.edit : t.newGoal,
      leading: DLAppBarLeading.close,
      onLeading: () => popOr(context, Routes.goals),
    );
    if (_loading) return Scaffold(appBar: appBar, body: const SizedBox.shrink());

    return Scaffold(
      appBar: appBar,
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          DLTextField(
            controller: _title,
            label: t.title,
            hint: t.phGoalT,
            error: _error,
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          DLField(
            label: t.category,
            child: Wrap(
              spacing: DLSpace.s2,
              runSpacing: 0,
              children: [
                for (final cat in GoalCategory.values)
                  DLChip(label: goalCategoryLabel(t, cat), selected: cat == _category, onTap: () => setState(() => _category = cat)),
              ],
            ),
          ),
          DLTextField(controller: _desc, label: t.desc, hint: t.phDesc, multiline: true),
          DLPickerField(
            label: t.targetDate,
            value: f.dateMedium(_date),
            helper: f.dateLong(_date),
            icon: DLIcons.calendar,
            onTap: () async {
              final d = await pickDate(context, _date);
              if (d != null && mounted) setState(() => _date = d);
            },
          ),
          if (widget.editId == null)
            DLTextField(controller: _milestones, label: t.milestones, optionalLabel: t.optional, hint: t.msPerLine, multiline: true),
          const SizedBox(height: DLSpace.s2),
          Row(
            children: [
              Expanded(
                child: DLButton(label: t.cancel, variant: DLButtonVariant.secondary, onPressed: () => popOr(context, Routes.goals)),
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
