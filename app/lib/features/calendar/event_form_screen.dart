import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';
import '../../core/format/dl_format_more.dart';
import '../../core/format/format_provider.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import 'calendar_providers.dart';
import 'calendar_ui.dart';

/// Add / edit an event (prototype `addEvent`, screenshot 44). A title is
/// required and the end can't come before the start. A new event lands on its
/// details; the calendar moves to its date.
class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({super.key}) : editId = null;

  const EventFormScreen.edit({super.key, required String id}) : editId = id;

  final String? editId;

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _desc = TextEditingController();
  EventCategory _category = EventCategory.meeting;
  // New events start on the calendar's selected day (prototype `calSel`).
  late DateTime _date = ref.read(calendarProvider).selected;
  late DateTime _endDate = _date;
  bool _allDay = false;
  String _start = '10:00';
  String _end = '11:00';
  int _reminder = 30;
  RepeatRule _repeat = RepeatRule.once;
  Event? _original;
  late bool _loading = widget.editId != null;
  Map<String, String> _errors = const {};

  @override
  void initState() {
    super.initState();
    if (widget.editId != null) _load(widget.editId!);
  }

  Future<void> _load(String id) async {
    final e = await ref.read(calendarDaoProvider).eventById(id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (e == null) return;
      _original = e;
      _title.text = e.title;
      _location.text = e.location;
      _desc.text = e.description;
      _category = e.category;
      _date = e.startDate;
      _endDate = e.endDate;
      _allDay = e.startTime == null || e.startTime!.isEmpty;
      if (!_allDay) {
        _start = e.startTime!;
        _end = e.endTime ?? e.startTime!;
      }
      _reminder = e.reminderMinutes;
      _repeat = e.repeat;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _clearError(String key) {
    if (_errors.containsKey(key)) setState(() => _errors = {..._errors}..remove(key));
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final title = _title.text.trim();
    final badEnd = _endDate.isBefore(_date) || (!_allDay && dayKey(_endDate) == dayKey(_date) && minutesBetween(_start, _end) <= 0);
    final errors = {
      if (title.isEmpty) 'title': t.errTitle,
      if (badEnd) 'end': t.errEnd,
    };
    setState(() => _errors = errors);
    if (errors.isNotEmpty) {
      DLToast.show(context, t.errForm, error: true);
      return;
    }
    final dao = ref.read(calendarDaoProvider);
    final original = _original;
    final String id;
    if (original != null) {
      id = original.id;
      await dao.updateEvent(original.copyWith(
        title: title,
        category: _category,
        startDate: _date,
        endDate: _endDate,
        startTime: Value(_allDay ? null : _start),
        endTime: Value(_allDay ? null : _end),
        location: _location.text.trim(),
        reminderMinutes: _reminder,
        repeat: _repeat,
        description: _desc.text.trim(),
      ));
    } else {
      id = await dao.addEvent(EventsCompanion.insert(
        title: title,
        category: _category,
        startDate: _date,
        endDate: _endDate,
        startTime: Value(_allDay ? null : _start),
        endTime: Value(_allDay ? null : _end),
        location: Value(_location.text.trim()),
        reminderMinutes: Value(_reminder),
        repeat: _repeat,
        description: Value(_desc.text.trim()),
      ));
    }
    if (!mounted) return;
    ref.read(calendarProvider.notifier).select(_date);
    DLToast.show(context, t.eventSaved);
    if (original != null) {
      popOr(context, Routes.calendar);
    } else {
      context.pushReplacement(Routes.event(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final appBar = DLAppBar(
      title: widget.editId != null ? t.editEvent : t.addEvent,
      leading: DLAppBarLeading.close,
      onLeading: () => popOr(context, Routes.calendar),
    );
    if (_loading) return Scaffold(appBar: appBar, body: const SizedBox.shrink());

    Future<void> pickDay(bool end) async {
      final d = await pickDate(context, end ? _endDate : _date);
      if (d == null || !mounted) return;
      setState(() {
        if (end) {
          _endDate = d;
        } else {
          // Moving the start past the end moves the end with it.
          if (_endDate.isBefore(d) || dayKey(_endDate) == dayKey(_date)) _endDate = d;
          _date = d;
        }
      });
      _clearError('end');
    }

    Future<void> pickHm(bool end) async {
      final hm = await pickTime(context, end ? _end : _start);
      if (hm == null || !mounted) return;
      setState(() {
        if (end) {
          _end = hm;
        } else {
          _start = hm;
        }
      });
      _clearError('end');
    }

    Widget pair(Widget a, Widget? b) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: DLSpace.s3),
            Expanded(child: b ?? const SizedBox.shrink()),
          ],
        );

    final when = _allDay ? '${f.dateLong(_date)} · ${t.allDay}' : '${f.dateLong(_date)} · ${f.time(_start)} – ${f.time(_end)}';

    return Scaffold(
      appBar: appBar,
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          DLTextField(
            controller: _title,
            label: t.title,
            hint: t.phEvent,
            error: _errors['title'],
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearError('title'),
          ),
          DLField(
            label: t.category,
            child: Wrap(
              spacing: DLSpace.s2,
              runSpacing: 0,
              children: [
                for (final cat in EventCategory.values)
                  DLChip(
                    label: eventCategoryLabel(t, cat),
                    leading: DLDot(color: eventColor(c, cat)),
                    selected: cat == _category,
                    onTap: () => setState(() => _category = cat),
                  ),
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
                  Expanded(child: Text(t.allDay, style: DLText.textLabel.copyWith(color: c.textPrimary))),
                  DLSwitch(
                    value: _allDay,
                    semanticLabel: t.allDay,
                    onChanged: (v) {
                      setState(() => _allDay = v);
                      _clearError('end');
                    },
                  ),
                ],
              ),
            ),
          ),
          pair(
            DLPickerField(label: t.startDate, value: f.dateMedium(_date), icon: DLIcons.calendar, onTap: () => pickDay(false)),
            _allDay ? null : DLPickerField(label: t.startTime, value: f.time(_start), icon: DLIcons.clock, onTap: () => pickHm(false)),
          ),
          pair(
            DLPickerField(
              label: t.endDate,
              value: f.dateMedium(_endDate),
              icon: DLIcons.calendar,
              error: _allDay ? _errors['end'] : null,
              onTap: () => pickDay(true),
            ),
            _allDay
                ? null
                : DLPickerField(label: t.endTime, value: f.time(_end), icon: DLIcons.clock, error: _errors['end'], onTap: () => pickHm(true)),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: DLSpace.s3),
            child: Text(when, style: DLText.textBodySm.copyWith(color: c.textSecondary)),
          ),
          DLTextField(controller: _location, label: t.location, hint: t.phLoc),
          DLField(
            label: t.reminder,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (i, m) in reminderChoices.indexed) ...[
                    if (i > 0) const SizedBox(width: DLSpace.s2),
                    DLChip(label: reminderLabel(t, m), selected: m == _reminder, onTap: () => setState(() => _reminder = m)),
                  ],
                ],
              ),
            ),
          ),
          DLField(
            label: t.repeat,
            child: Wrap(
              spacing: DLSpace.s2,
              runSpacing: 0,
              children: [
                for (final r in [RepeatRule.once, RepeatRule.daily, RepeatRule.weekly, RepeatRule.monthly])
                  DLChip(label: repeatLabel(t, r), selected: r == _repeat, onTap: () => setState(() => _repeat = r)),
              ],
            ),
          ),
          DLTextField(controller: _desc, label: t.desc, hint: t.phDesc, multiline: true),
          const SizedBox(height: DLSpace.s2),
          Row(
            children: [
              Expanded(
                child: DLButton(label: t.cancel, variant: DLButtonVariant.secondary, onPressed: () => popOr(context, Routes.calendar)),
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
