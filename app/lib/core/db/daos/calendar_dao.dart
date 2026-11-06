import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'calendar_dao.g.dart';

/// Calendar events. Repeats (daily / weekly / monthly) are expanded per day by
/// the Calendar feature; this stores each event once.
@DriftAccessor(tables: [Events])
class CalendarDao extends DatabaseAccessor<AppDatabase> with _$CalendarDaoMixin {
  CalendarDao(super.attachedDatabase);

  /// All events by start date and time (all-day first within a day: SQLite
  /// sorts the null start time first).
  Stream<List<Event>> watchEvents() =>
      (select(events)..orderBy([(e) => OrderingTerm.asc(e.startDate), (e) => OrderingTerm.asc(e.startTime)])).watch();

  Future<List<Event>> allEvents() => (select(events)..orderBy([(e) => OrderingTerm.asc(e.startDate)])).get();

  Future<Event?> eventById(String id) => (select(events)..where((e) => e.id.equals(id))).getSingleOrNull();

  Stream<Event?> watchEvent(String id) => (select(events)..where((e) => e.id.equals(id))).watchSingleOrNull();

  /// Inserts [row] and returns its id.
  Future<String> addEvent(EventsCompanion row) async {
    final id = row.id.present ? row.id.value : newId();
    await into(events).insert(row.copyWith(id: Value(id)));
    return id;
  }

  Future<bool> updateEvent(Event row) => update(events).replace(row);

  Future<int> deleteEvent(String id) => (delete(events)..where((e) => e.id.equals(id))).go();
}
