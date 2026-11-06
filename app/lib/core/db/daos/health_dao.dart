import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'health_dao.g.dart';

/// A habit and the days it was done.
class HabitWithChecks {
  const HabitWithChecks(this.habit, this.dayKeys);

  final Habit habit;

  /// Done days as `yyyy-MM-dd`.
  final Set<String> dayKeys;

  bool isDoneOn(DateTime day) => dayKeys.contains(dayKey(day));
}

@DriftAccessor(tables: [WaterEntries, Meals, Habits, HabitChecks])
class HealthDao extends DatabaseAccessor<AppDatabase> with _$HealthDaoMixin {
  HealthDao(super.attachedDatabase);

  // ------------------------------------------------------------ water

  /// [day]'s glasses, latest first.
  Stream<List<WaterEntry>> watchWaterOn(DateTime day) => (select(waterEntries)
        ..where((w) => w.date.equalsValue(dateOnly(day)))
        ..orderBy([(w) => OrderingTerm.desc(w.time)]))
      .watch();

  /// Millilitres per day (`yyyy-MM-dd`) in [range]; days without water are absent.
  Stream<Map<String, int>> watchWaterTotals(DayRange range) => customSelect(
        'SELECT date, SUM(ml) AS ml FROM water_entries WHERE date >= ?1 AND date < ?2 GROUP BY date',
        variables: [Variable.withString(range.start), Variable.withString(range.end)],
        readsFrom: {waterEntries},
      ).watch().map((rows) => {for (final r in rows) r.read<String>('date'): r.read<int>('ml')});

  Future<String> addWater({required DateTime date, required String time, required int ml}) async {
    final id = newId();
    await into(waterEntries).insert(WaterEntriesCompanion.insert(id: Value(id), date: dateOnly(date), time: time, ml: ml));
    return id;
  }

  Future<int> deleteWater(String id) => (delete(waterEntries)..where((w) => w.id.equals(id))).go();

  // ------------------------------------------------------------ meals

  /// [day]'s meals by time.
  Stream<List<Meal>> watchMealsOn(DateTime day) => (select(meals)
        ..where((m) => m.date.equalsValue(dateOnly(day)))
        ..orderBy([(m) => OrderingTerm.asc(m.time)]))
      .watch();

  /// Meals before [day], newest day first and by time within a day (the
  /// meal history).
  Stream<List<Meal>> watchMealsBefore(DateTime day) => (select(meals)
        ..where((m) => m.date.isSmallerThanValue(dayKey(day)))
        ..orderBy([(m) => OrderingTerm.desc(m.date), (m) => OrderingTerm.asc(m.time)]))
      .watch();

  Future<Meal?> mealById(String id) => (select(meals)..where((m) => m.id.equals(id))).getSingleOrNull();

  /// Inserts [row] and returns its id.
  Future<String> addMeal(MealsCompanion row) async {
    final id = row.id.present ? row.id.value : newId();
    await into(meals).insert(row.copyWith(id: Value(id)));
    return id;
  }

  Future<bool> updateMeal(Meal row) => update(meals).replace(row);

  Future<int> deleteMeal(String id) => (delete(meals)..where((m) => m.id.equals(id))).go();

  // ------------------------------------------------------------ habits

  /// Habits in creation order with their done days.
  Stream<List<HabitWithChecks>> watchHabits() => customSelect(
        'SELECT habit_id, date FROM habit_checks',
        readsFrom: {habits, habitChecks},
      ).watch().asyncMap((rows) async {
        final byHabit = <String, Set<String>>{};
        for (final r in rows) {
          (byHabit[r.read<String>('habit_id')] ??= <String>{}).add(r.read<String>('date'));
        }
        final list = await (select(habits)..orderBy([(h) => OrderingTerm.asc(h.createdAt)])).get();
        return [for (final h in list) HabitWithChecks(h, byHabit[h.id] ?? const <String>{})];
      });

  Future<String> addHabit({required String name, String icon = 'flame', String? reminderTime}) async {
    final id = newId();
    await into(habits).insert(HabitsCompanion.insert(id: Value(id), name: name, icon: Value(icon), reminderTime: Value(reminderTime)));
    return id;
  }

  Future<bool> updateHabit(Habit row) => update(habits).replace(row);

  /// Deletes the habit and its history.
  Future<int> deleteHabit(String id) => (delete(habits)..where((h) => h.id.equals(id))).go();

  /// Marks [day] done or not done.
  Future<void> setDone(String habitId, DateTime day, bool done) async {
    if (done) {
      await into(habitChecks).insert(HabitChecksCompanion.insert(habitId: habitId, date: dateOnly(day)), mode: InsertMode.insertOrIgnore);
    } else {
      await (delete(habitChecks)..where((c) => c.habitId.equals(habitId) & c.date.equalsValue(dateOnly(day)))).go();
    }
  }

  /// Flips [day] and returns whether it is now done.
  Future<bool> toggle(String habitId, DateTime day) => transaction(() async {
        final existing = await (select(habitChecks)..where((c) => c.habitId.equals(habitId) & c.date.equalsValue(dateOnly(day)))).getSingleOrNull();
        await setDone(habitId, day, existing == null);
        return existing == null;
      });
}
