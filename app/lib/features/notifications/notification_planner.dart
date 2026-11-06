// What should be pending as device notifications, from the data and the
// Settings toggles (brief: "Schedule real notifications for enabled reminders,
// event reminders, water (every 2 h 8 AM–10 PM) and meals when their settings
// are on"). Pure: the clock, strings and formatter come in as arguments.
import '../../core/db/app_database.dart';
import '../../core/format/dl_format.dart';
import '../../core/notifications/notification_scheduler.dart';
import '../../core/prefs/notification_prefs.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../calendar/calendar_ui.dart';
import '../calendar/event_rules.dart';

/// Water reminders: every 2 hours from 8 AM to 10 PM.
const waterHours = [8, 10, 12, 14, 16, 18, 20, 22];

/// Meal reminders at the prototype's usual meal times.
const mealTimes = {
  MealType.breakfast: '08:00',
  MealType.lunch: '13:30',
  MealType.snack: '17:00',
  MealType.dinner: '21:00',
};

/// All-day events remind relative to 9 AM.
const allDayEventTime = '09:00';

/// Event reminders are planned this many days ahead (repeats included); the
/// plan is rebuilt on every change and whenever the app opens.
const eventWindowDays = 30;

DateTime _at(DateTime day, String hm) {
  final p = hm.split(':').map(int.parse).toList();
  return DateTime(day.year, day.month, day.day, p[0], p.length > 1 ? p[1] : 0);
}

/// Reminders outside Office follow "General reminders"; Office ones "Office
/// reminders".
bool _reminderAllowed(Reminder r, NotificationPrefs prefs) =>
    r.category == ReminderCategory.office ? prefs[NotifKind.office] : prefs[NotifKind.general];

/// Reminder weekdays are 0 = Saturday … 6 = Friday; Dart's are 1 = Monday … 7 = Sunday.
int dartWeekday(int satFirst) => (satFirst + 5) % 7 + 1;

List<PlannedNotification> planNotifications({
  required DateTime now,
  required NotificationPrefs prefs,
  required List<Reminder> reminders,
  required List<Event> events,
  required AppLocalizations t,
  required DLFormat f,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final plan = <PlannedNotification>[];

  // ---------------------------------------------------------- reminders
  for (final r in reminders) {
    if (!r.enabled || r.done || !_reminderAllowed(r, prefs)) continue;
    final body = r.description.isEmpty ? f.time(r.time) : r.description;
    PlannedNotification note(DateTime at, NotifRepeat repeat) =>
        PlannedNotification(at: at, title: r.title, body: body, route: Routes.reminder(r.id), repeat: repeat);
    final start = _at(r.date, r.time);
    final days = r.repeat == RepeatRule.custom ? (r.customDays.toList()..sort()) : const <int>[];

    switch (r.repeat) {
      case RepeatRule.once:
        if (start.isAfter(now)) plan.add(note(start, NotifRepeat.none));
      case RepeatRule.custom when days.isEmpty:
        if (start.isAfter(now)) plan.add(note(start, NotifRepeat.none));
      case RepeatRule.daily:
        var at = start;
        if (!at.isAfter(now)) {
          at = _at(today, r.time);
          if (!at.isAfter(now)) at = _at(DateTime(today.year, today.month, today.day + 1), r.time);
        }
        plan.add(note(at, NotifRepeat.daily));
      case RepeatRule.weekly:
        var at = start;
        while (!at.isAfter(now)) {
          at = _at(DateTime(at.year, at.month, at.day + 7), r.time);
        }
        plan.add(note(at, NotifRepeat.weekly));
      case RepeatRule.monthly:
        var at = start;
        for (var m = 1; !at.isAfter(now); m++) {
          at = _at(DateTime(r.date.year, r.date.month + m, r.date.day), r.time);
        }
        plan.add(note(at, NotifRepeat.monthly));
      case RepeatRule.custom:
        // One weekly notification per chosen weekday, from the start date on.
        final from = r.date.isAfter(today) ? r.date : today;
        for (final d in days) {
          var day = from;
          while (day.weekday != dartWeekday(d)) {
            day = DateTime(day.year, day.month, day.day + 1);
          }
          var at = _at(day, r.time);
          if (!at.isAfter(now)) at = _at(DateTime(day.year, day.month, day.day + 7), r.time);
          plan.add(note(at, NotifRepeat.weekly));
        }
    }
  }

  // ---------------------------------------------------------- events
  if (prefs[NotifKind.calendar]) {
    for (final e in events) {
      if (e.reminderMinutes <= 0) continue;
      final body = e.location.isEmpty ? eventTime(t, f, e) : '${eventTime(t, f, e)} · ${e.location}';
      final start = e.startTime;
      final time = start == null || start.isEmpty ? allDayEventTime : start;
      // One-off events remind before their first day; repeats before each.
      final days = e.repeat == RepeatRule.once || e.repeat == RepeatRule.custom
          ? [dateOnly(e.startDate)]
          : [
              for (var i = 0; i <= eventWindowDays; i++)
                if (eventOccursOn(e, DateTime(today.year, today.month, today.day + i))) DateTime(today.year, today.month, today.day + i),
            ];
      for (final day in days) {
        final at = _at(day, time).subtract(Duration(minutes: e.reminderMinutes));
        if (at.isAfter(now)) plan.add(PlannedNotification(at: at, title: e.title, body: body, route: Routes.event(e.id)));
      }
    }
  }

  // ---------------------------------------------------------- health
  if (prefs[NotifKind.water]) {
    for (final h in waterHours) {
      var at = DateTime(today.year, today.month, today.day, h);
      if (!at.isAfter(now)) at = DateTime(today.year, today.month, today.day + 1, h);
      plan.add(PlannedNotification(
        at: at,
        title: t.water,
        body: t.notifWater,
        route: Routes.more,
        repeat: NotifRepeat.daily,
        channel: NotifChannel.health,
      ));
    }
  }
  if (prefs[NotifKind.meal]) {
    for (final MapEntry(key: meal, value: hm) in mealTimes.entries) {
      var at = _at(today, hm);
      if (!at.isAfter(now)) at = _at(DateTime(today.year, today.month, today.day + 1), hm);
      plan.add(PlannedNotification(
        at: at,
        title: mealLabel(t, meal),
        body: t.mealDesc,
        route: Routes.more,
        repeat: NotifRepeat.daily,
        channel: NotifChannel.health,
      ));
    }
  }

  plan.sort((a, b) => a.at.compareTo(b.at));
  return plan;
}

String mealLabel(AppLocalizations t, MealType m) => switch (m) {
      MealType.breakfast => t.breakfast,
      MealType.lunch => t.lunch,
      MealType.snack => t.snack,
      MealType.dinner => t.dinner,
    };
