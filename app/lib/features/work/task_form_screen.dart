import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';
import '../../core/format/dl_format_more.dart';
import '../../core/format/format_provider.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import 'project_sheet.dart';
import 'work_providers.dart';
import 'work_ui.dart';

/// Add work / edit a task (prototype `addTask`, screenshot 31). The name and a
/// project are required, and the end time must come after the start.
class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({super.key, this.projectId}) : editId = null;

  const TaskFormScreen.edit({super.key, required String id})
      : editId = id,
        projectId = null;

  /// Preselected project (from a project's "Add").
  final String? projectId;
  final String? editId;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _note = TextEditingController();
  String? _projectId;
  late DateTime _date = dateOnly(ref.read(clockProvider)());
  String _start = '10:00';
  String _end = '11:00';
  TaskStatus _status = TaskStatus.todo;
  PriorityLevel _priority = PriorityLevel.medium;
  Task? _original;
  late bool _loading = widget.editId != null;
  Map<String, String> _errors = const {};

  @override
  void initState() {
    super.initState();
    if (widget.editId != null) {
      _load(widget.editId!);
    } else {
      _projectId = widget.projectId;
      // Like the prototype: a new task starts in the first project.
      if (_projectId == null) _firstProject();
    }
  }

  Future<void> _firstProject() async {
    final all = await ref.read(workDaoProvider).watchProjects().first;
    if (!mounted || _projectId != null || all.isEmpty) return;
    setState(() => _projectId = all.first.id);
  }

  Future<void> _load(String id) async {
    final k = await ref.read(workDaoProvider).taskById(id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (k == null) return;
      _original = k;
      _title.text = k.title;
      _desc.text = k.description;
      _note.text = k.note;
      _projectId = k.projectId;
      _date = k.date;
      _start = k.startTime;
      _end = k.endTime;
      _status = k.status;
      _priority = k.priority;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _note.dispose();
    super.dispose();
  }

  void _clearError(String key) {
    if (_errors.containsKey(key)) setState(() => _errors = {..._errors}..remove(key));
  }

  Future<void> _newProject() async {
    final id = await showNewProjectSheet(context);
    if (id == null || !mounted) return;
    setState(() => _projectId = id);
    _clearError('project');
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final title = _title.text.trim();
    final errors = {
      if (title.isEmpty) 'title': t.errTitle,
      if (_projectId == null) 'project': t.errCat,
      if (minutesBetween(_start, _end) <= 0) 'end': t.errEnd,
    };
    setState(() => _errors = errors);
    if (errors.isNotEmpty) {
      DLToast.show(context, t.errForm, error: true);
      return;
    }
    final dao = ref.read(workDaoProvider);
    final original = _original;
    if (original != null) {
      await dao.updateTask(original.copyWith(
        title: title,
        projectId: Value(_projectId),
        description: _desc.text.trim(),
        date: _date,
        startTime: _start,
        endTime: _end,
        status: _status,
        priority: _priority,
        note: _note.text.trim(),
      ));
    } else {
      await dao.addTask(TasksCompanion.insert(
        title: title,
        projectId: Value(_projectId),
        description: Value(_desc.text.trim()),
        date: _date,
        startTime: _start,
        endTime: _end,
        status: _status,
        priority: _priority,
        note: Value(_note.text.trim()),
      ));
    }
    if (!mounted) return;
    DLToast.show(context, t.taskSaved);
    popOr(context, Routes.work);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final appBar = DLAppBar(
      title: widget.editId != null ? t.editTask : t.addWork,
      leading: DLAppBarLeading.close,
      onLeading: () => popOr(context, Routes.work),
    );
    if (_loading) return Scaffold(appBar: appBar, body: const SizedBox.shrink());
    final minutes = minutesBetween(_start, _end);

    Widget chips<T>(List<(T, String)> options, T value, ValueChanged<T> onPick) => Wrap(
          spacing: DLSpace.s2,
          runSpacing: 0,
          children: [for (final (v, label) in options) DLChip(label: label, selected: v == value, onTap: () => onPick(v))],
        );

    return Scaffold(
      appBar: appBar,
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          DLTextField(
            controller: _title,
            label: t.taskName,
            hint: t.phTask,
            error: _errors['title'],
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearError('title'),
          ),
          DLField(
            label: t.project,
            error: _errors['project'],
            child: Wrap(
              spacing: DLSpace.s2,
              runSpacing: 0,
              children: [
                for (final p in projects)
                  DLChip(
                    label: p.name,
                    selected: p.id == _projectId,
                    onTap: () {
                      setState(() => _projectId = p.id);
                      _clearError('project');
                    },
                  ),
                DLChip(label: t.newProject, icon: DLIcons.plus, dashed: true, onTap: _newProject),
              ],
            ),
          ),
          DLTextField(controller: _desc, label: t.desc, hint: t.phDesc, multiline: true),
          DLPickerField(
            label: t.date,
            value: f.dateMedium(_date),
            helper: f.dateLong(_date),
            icon: DLIcons.calendar,
            onTap: () async {
              final d = await pickDate(context, _date);
              if (d != null && mounted) setState(() => _date = d);
            },
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DLPickerField(
                  label: t.startTime,
                  value: f.time(_start),
                  icon: DLIcons.clock,
                  onTap: () async {
                    final hm = await pickTime(context, _start);
                    if (hm == null || !mounted) return;
                    setState(() => _start = hm);
                    _clearError('end');
                  },
                ),
              ),
              const SizedBox(width: DLSpace.s3),
              Expanded(
                child: DLPickerField(
                  label: t.endTime,
                  value: f.time(_end),
                  icon: DLIcons.clock,
                  error: _errors['end'],
                  onTap: () async {
                    final hm = await pickTime(context, _end);
                    if (hm == null || !mounted) return;
                    setState(() => _end = hm);
                    _clearError('end');
                  },
                ),
              ),
            ],
          ),
          // The duration well (prototype: a sunken card row).
          Container(
            margin: const EdgeInsets.only(bottom: DLSpace.s4),
            padding: const EdgeInsets.symmetric(horizontal: DLSpace.s4, vertical: DLSpace.s3),
            decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(DLRadius.lg)),
            child: Row(
              children: [
                Icon(DLIcons.clock, size: 20, color: c.textSecondary),
                const SizedBox(width: DLSpace.s3),
                Expanded(child: Text(t.duration, style: DLText.textLabel.copyWith(color: c.textPrimary))),
                Text(minutes > 0 ? f.duration(minutes) : '—', style: DLText.amountMd.copyWith(color: c.textPrimary)),
              ],
            ),
          ),
          DLField(
            label: t.status,
            child: chips([for (final s in TaskStatus.values) (s, statusLabel(t, s))], _status, (s) => setState(() => _status = s)),
          ),
          DLField(
            label: t.priority,
            child: chips([for (final p in PriorityLevel.values) (p, priorityLabel(t, p))], _priority, (p) => setState(() => _priority = p)),
          ),
          DLTextField(controller: _note, label: t.note, optionalLabel: t.optional, hint: t.phNote),
          const SizedBox(height: DLSpace.s2),
          Row(
            children: [
              Expanded(
                child: DLButton(label: t.cancel, variant: DLButtonVariant.secondary, onPressed: () => popOr(context, Routes.work)),
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
