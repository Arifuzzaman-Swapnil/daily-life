// When a calendar event happens (prototype `occurs` / `evOn`). Events are stored
// once; repeats are expanded per day here, for Home's today tiles now and the
// Calendar screens in build step 6.
import '../../core/db/app_database.dart';

/// Whether [e] happens on [day]. Nothing before its start date; then daily =
/// every day, weekly = the same weekday, monthly = the same day of the month,
/// once = every day from the start to the end date.
bool eventOccursOn(Event e, DateTime day) {
  final d = dateOnly(day);
  final start = dateOnly(e.startDate);
  if (d.isBefore(start)) return false;
  return switch (e.repeat) {
    RepeatRule.daily => true,
    // Calendar days, so a daylight-saving shift can't skew the count.
    RepeatRule.weekly => DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(start.year, start.month, start.day)).inDays % 7 == 0,
    RepeatRule.monthly => d.day == start.day,
    RepeatRule.once || RepeatRule.custom => !d.isAfter(dateOnly(e.endDate)),
  };
}

/// [events] that happen on [day], by start time (all-day events first), keeping
/// the given order for equal times.
List<Event> eventsOn(Iterable<Event> events, DateTime day) {
  final list = [
    for (final e in events)
      if (eventOccursOn(e, day)) e,
  ];
  final position = {for (final (i, e) in list.indexed) e.id: i};
  return list
    ..sort((a, b) {
      final byTime = (a.startTime ?? '00').compareTo(b.startTime ?? '00');
      return byTime != 0 ? byTime : position[a.id]!.compareTo(position[b.id]!);
    });
}
