import 'package:dailylife/core/db/app_database.dart';
import 'package:dailylife/features/calendar/event_rules.dart';
import 'package:flutter_test/flutter_test.dart';

Event ev(String id, RepeatRule repeat, DateTime start, {DateTime? end, String? time}) => Event(
      id: id,
      title: id,
      category: EventCategory.other,
      startDate: start,
      endDate: end ?? start,
      startTime: time,
      endTime: null,
      location: '',
      reminderMinutes: 0,
      repeat: repeat,
      description: '',
      createdAt: DateTime(2026),
    );

void main() {
  final start = DateTime(2026, 11, 6); // a Friday

  test('nothing happens before the start date', () {
    for (final r in RepeatRule.values) {
      expect(eventOccursOn(ev('e', r, start), DateTime(2026, 11, 5)), isFalse, reason: r.name);
      expect(eventOccursOn(ev('e', r, start), start), isTrue, reason: r.name);
    }
  });

  test('once covers the start to end range', () {
    final e = ev('e', RepeatRule.once, start, end: DateTime(2026, 11, 8));
    expect(eventOccursOn(e, DateTime(2026, 11, 7)), isTrue);
    expect(eventOccursOn(e, DateTime(2026, 11, 8, 23, 59)), isTrue);
    expect(eventOccursOn(e, DateTime(2026, 11, 9)), isFalse);
  });

  test('daily, weekly (same weekday) and monthly (same day of month)', () {
    expect(eventOccursOn(ev('d', RepeatRule.daily, start), DateTime(2027, 3, 1)), isTrue);
    final weekly = ev('w', RepeatRule.weekly, start);
    expect(eventOccursOn(weekly, DateTime(2026, 11, 13)), isTrue);
    expect(eventOccursOn(weekly, DateTime(2027, 4, 2)), isTrue); // across the year end
    expect(eventOccursOn(weekly, DateTime(2026, 11, 14)), isFalse);
    final monthly = ev('m', RepeatRule.monthly, DateTime(2026, 11, 1));
    expect(eventOccursOn(monthly, DateTime(2026, 12, 1)), isTrue);
    expect(eventOccursOn(monthly, DateTime(2026, 12, 2)), isFalse);
  });

  test('eventsOn sorts by start time, all-day first, keeping order for ties', () {
    final list = eventsOn([
      ev('late', RepeatRule.once, start, time: '19:30'),
      ev('allDay', RepeatRule.monthly, DateTime(2026, 10, 6)),
      ev('early', RepeatRule.weekly, DateTime(2026, 10, 30), time: '10:00'),
      ev('tieA', RepeatRule.once, start, time: '12:00'),
      ev('tieB', RepeatRule.daily, DateTime(2026, 11, 1), time: '12:00'),
      ev('tomorrow', RepeatRule.once, DateTime(2026, 11, 7)),
    ], start);
    expect([for (final e in list) e.id], ['allDay', 'early', 'tieA', 'tieB', 'late']);
  });
}
