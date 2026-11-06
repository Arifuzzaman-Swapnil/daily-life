import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'reminders_dao.g.dart';

@DriftAccessor(tables: [Reminders])
class RemindersDao extends DatabaseAccessor<AppDatabase> with _$RemindersDaoMixin {
  RemindersDao(super.attachedDatabase);

  SimpleSelectStatement<$RemindersTable, Reminder> _sorted(Expression<bool> Function($RemindersTable r) filter) => select(reminders)
    ..where(filter)
    ..orderBy([(r) => OrderingTerm.asc(r.date), (r) => OrderingTerm.asc(r.time)]);

  /// The Today tab: not done and due today or earlier (overdue included).
  Stream<List<Reminder>> watchToday(DateTime today) =>
      _sorted((r) => r.done.equals(false) & r.date.isSmallerOrEqualValue(dayKey(today))).watch();

  /// The Upcoming tab: not done and due after today.
  Stream<List<Reminder>> watchUpcoming(DateTime today) => _sorted((r) => r.done.equals(false) & r.date.isBiggerThanValue(dayKey(today))).watch();

  /// The Completed tab.
  Stream<List<Reminder>> watchCompleted() => _sorted((r) => r.done.equals(true)).watch();

  /// Tab counts.
  Stream<({int today, int upcoming, int completed})> watchCounts(DateTime today) => customSelect(
        '''
SELECT COALESCE(SUM(CASE WHEN done = 0 AND date <= ?1 THEN 1 ELSE 0 END), 0) AS today,
       COALESCE(SUM(CASE WHEN done = 0 AND date > ?1 THEN 1 ELSE 0 END), 0) AS upcoming,
       COALESCE(SUM(CASE WHEN done = 1 THEN 1 ELSE 0 END), 0) AS completed
  FROM reminders''',
        variables: [Variable.withString(dayKey(today))],
        readsFrom: {reminders},
      ).watchSingle().map((r) => (today: r.read<int>('today'), upcoming: r.read<int>('upcoming'), completed: r.read<int>('completed')));

  /// Enabled, not-done reminders (for scheduling notifications).
  Future<List<Reminder>> activeReminders() => _sorted((r) => r.enabled.equals(true) & r.done.equals(false)).get();

  /// [activeReminders] as a stream: notifications follow every change.
  Stream<List<Reminder>> watchActive() => _sorted((r) => r.enabled.equals(true) & r.done.equals(false)).watch();

  Future<Reminder?> reminderById(String id) => (select(reminders)..where((r) => r.id.equals(id))).getSingleOrNull();

  Stream<Reminder?> watchReminder(String id) => (select(reminders)..where((r) => r.id.equals(id))).watchSingleOrNull();

  /// Inserts [row] and returns its id.
  Future<String> addReminder(RemindersCompanion row) async {
    final id = row.id.present ? row.id.value : newId();
    await into(reminders).insert(row.copyWith(id: Value(id)));
    return id;
  }

  Future<bool> updateReminder(Reminder row) => update(reminders).replace(row);

  Future<int> deleteReminder(String id) => (delete(reminders)..where((r) => r.id.equals(id))).go();

  Future<void> setDone(String id, bool done) =>
      (update(reminders)..where((r) => r.id.equals(id))).write(RemindersCompanion(done: Value(done)));

  Future<void> setEnabled(String id, bool enabled) =>
      (update(reminders)..where((r) => r.id.equals(id))).write(RemindersCompanion(enabled: Value(enabled)));

  /// Snooze: 10 minutes later the same day (the clock wraps past midnight, as in
  /// the prototype).
  Future<void> snooze(String id, {int minutes = 10}) => transaction(() async {
        final r = await reminderById(id);
        if (r == null) return;
        final p = r.time.split(':').map(int.parse).toList();
        final total = p[0] * 60 + p[1] + minutes;
        final hm = '${((total ~/ 60) % 24).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
        await (update(reminders)..where((x) => x.id.equals(id))).write(RemindersCompanion(time: Value(hm)));
      });
}
