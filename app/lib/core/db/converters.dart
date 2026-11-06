// Storage helpers shared by the tables, DAOs and seeder.
//
// Date-only values (a transaction's date, a task's day…) are stored as text
// `yyyy-MM-dd` and read back as a local-midnight `DateTime`. Text sorts like the
// date, so a month is the half-open range [`2026-11-01`, `2026-12-01`).
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// A new random row id (uuid v4). Seeded rows keep the sample ids instead.
String newId() => _uuid.v4();

String _p2(int n) => n.toString().padLeft(2, '0');

/// `yyyy-MM-dd` for the calendar day of [d].
String dayKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_p2(d.month)}-${_p2(d.day)}';

/// `yyyy-MM` for the month of [d].
String monthKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_p2(d.month)}';

/// Parses `yyyy-MM-dd` (or `yyyy-MM`, as the 1st) into a local-midnight `DateTime`.
DateTime parseDayKey(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), p.length > 2 ? int.parse(p[2]) : 1);
}

/// The calendar day of [d] at local midnight.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// A half-open range of days [start, end), as day keys for SQL comparisons.
class DayRange {
  DayRange(DateTime from, DateTime toExclusive)
      : start = dayKey(from),
        end = dayKey(toExclusive);

  /// The calendar month containing [d].
  factory DayRange.month(DateTime d) => DayRange(DateTime(d.year, d.month), DateTime(d.year, d.month + 1));

  /// The single day [d].
  factory DayRange.day(DateTime d) => DayRange(dateOnly(d), DateTime(d.year, d.month, d.day + 1));

  /// [days] days ending with (and including) [last].
  factory DayRange.lastDays(DateTime last, int days) =>
      DayRange(DateTime(last.year, last.month, last.day - days + 1), DateTime(last.year, last.month, last.day + 1));

  /// The calendar year containing [d].
  factory DayRange.year(DateTime d) => DayRange(DateTime(d.year), DateTime(d.year + 1));

  final String start;
  final String end;

  bool contains(DateTime d) {
    final k = dayKey(d);
    return k.compareTo(start) >= 0 && k.compareTo(end) < 0;
  }
}

/// Date-only column: `DateTime` (local midnight) ⇄ text `yyyy-MM-dd`.
class DateOnlyConverter extends TypeConverter<DateTime, String> {
  const DateOnlyConverter();

  @override
  DateTime fromSql(String fromDb) => parseDayKey(fromDb);

  @override
  String toSql(DateTime value) => dayKey(value);
}

/// Month column (salary month): `DateTime` (the 1st) ⇄ text `yyyy-MM`.
class MonthConverter extends TypeConverter<DateTime, String> {
  const MonthConverter();

  @override
  DateTime fromSql(String fromDb) => parseDayKey(fromDb);

  @override
  String toSql(DateTime value) => monthKey(value);
}

/// Weekdays of a custom repeat (0 = Saturday … 6 = Friday) ⇄ a 7-bit mask.
class WeekdaySetConverter extends TypeConverter<Set<int>, int> {
  const WeekdaySetConverter();

  @override
  Set<int> fromSql(int fromDb) => {
        for (var i = 0; i < 7; i++)
          if ((fromDb & (1 << i)) != 0) i,
      };

  @override
  int toSql(Set<int> value) => value.fold(0, (mask, d) => mask | (1 << d));
}
