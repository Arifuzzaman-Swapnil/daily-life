// Riverpod access to water, meals and habits, and the habit rules: streak,
// best streak, month completion.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/daos/health_dao.dart';
import '../../core/db/db_providers.dart';
import '../finance/money_providers.dart';
import '../home/home_providers.dart';

export '../home/home_providers.dart' show habitsProvider, todayMealsProvider, todayWaterProvider;

/// The Health screen's tabs (prototype `healthTab`); the route picks one.
enum HealthTab { water, food, habits }

/// Today's glasses, latest first.
final todayWaterLogProvider = StreamProvider<List<WaterEntry>>((ref) => ref.watch(healthDaoProvider).watchWaterOn(todayFrom(ref)));

/// Meals before today, newest day first.
final mealHistoryProvider = StreamProvider<List<Meal>>((ref) => ref.watch(healthDaoProvider).watchMealsBefore(todayFrom(ref)));

/// One habit with its days; null once deleted.
final habitProvider = Provider.family<HabitWithChecks?, String>((ref, id) {
  final all = ref.watch(habitsProvider).value ?? const <HabitWithChecks>[];
  for (final h in all) {
    if (h.habit.id == id) return h;
  }
  return null;
});

DateTime _prev(DateTime d) => DateTime(d.year, d.month, d.day - 1);

/// Consecutive done days ending today, or yesterday when today isn't done yet.
int currentStreak(Set<String> days, DateTime today) {
  var d = dateOnly(today);
  if (!days.contains(dayKey(d))) d = _prev(d);
  var n = 0;
  while (days.contains(dayKey(d))) {
    n++;
    d = _prev(d);
  }
  return n;
}

/// The longest run of consecutive done days.
int bestStreak(Set<String> days) {
  final sorted = days.map(parseDayKey).toList()..sort();
  var best = 0, run = 0;
  DateTime? prev;
  for (final d in sorted) {
    run = prev != null && dayKey(DateTime(prev.year, prev.month, prev.day + 1)) == dayKey(d) ? run + 1 : 1;
    if (run > best) best = run;
    prev = d;
  }
  return best;
}

/// Done days this month / days elapsed (today included), 0–100.
double monthCompletion(Set<String> days, DateTime today) {
  final prefix = dayKey(today).substring(0, 7);
  final done = days.where((k) => k.startsWith(prefix)).length;
  return (done / today.day * 100).clamp(0, 100).toDouble();
}
