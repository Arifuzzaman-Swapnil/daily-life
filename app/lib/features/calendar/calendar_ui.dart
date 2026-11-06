// Shared Calendar pieces: category colours, tones and labels, reminder and
// repeat labels, an event's time text, and the day-cell dots.
import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';
import '../../core/format/dl_format.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import 'event_rules.dart';

/// A category's mark colour (prototype `evCol`): dots, legend, chips.
Color eventColor(DLColors c, EventCategory cat) => switch (cat) {
      EventCategory.office => c.chart2,
      EventCategory.meeting => c.accent,
      EventCategory.personal => c.catTask,
      EventCategory.family => c.warning,
      EventCategory.important => c.danger,
      EventCategory.other => c.borderStrong,
    };

/// A category's tag tone (prototype `evTag`).
DLTone eventTone(EventCategory cat) => switch (cat) {
      EventCategory.office || EventCategory.meeting => DLTone.accent,
      EventCategory.personal => DLTone.teal,
      EventCategory.family => DLTone.warning,
      EventCategory.important => DLTone.danger,
      EventCategory.other => DLTone.neutral,
    };

String eventCategoryLabel(AppLocalizations t, EventCategory cat) => switch (cat) {
      EventCategory.office => t.ev_office,
      EventCategory.meeting => t.ev_meeting,
      EventCategory.personal => t.ev_personal,
      EventCategory.family => t.ev_family,
      EventCategory.important => t.ev_important,
      EventCategory.other => t.ev_other,
    };

/// The event reminder choices, in minutes before.
const reminderChoices = [0, 10, 30, 60, 1440];

String reminderLabel(AppLocalizations t, int minutes) => switch (minutes) {
      10 => t.rm_10,
      30 => t.rm_30,
      60 => t.rm_60,
      1440 => t.rm_1440,
      _ => t.rm_0,
    };

String repeatLabel(AppLocalizations t, RepeatRule r) => switch (r) {
      RepeatRule.once => t.rp_once,
      RepeatRule.daily => t.rp_daily,
      RepeatRule.weekly => t.rp_weekly,
      RepeatRule.monthly => t.rp_monthly,
      RepeatRule.custom => t.rp_custom,
    };

/// "10:00 AM – 10:30 AM", "10:00 AM", or "All day".
String eventTime(AppLocalizations t, DLFormat f, Event e) {
  final start = e.startTime;
  if (start == null || start.isEmpty) return t.allDay;
  final end = e.endTime;
  return end == null || end.isEmpty ? f.time(start) : '${f.time(start)} – ${f.time(end)}';
}

/// Up to 3 category colours of the events on [day] (prototype `dots`).
List<Color> dayDots(DLColors c, List<Event> events, DateTime day) {
  final cats = <EventCategory>[];
  for (final e in eventsOn(events, day)) {
    if (!cats.contains(e.category)) cats.add(e.category);
  }
  return [for (final cat in cats.take(3)) eventColor(c, cat)];
}
