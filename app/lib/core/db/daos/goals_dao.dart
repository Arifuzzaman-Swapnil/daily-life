import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'goals_dao.g.dart';

/// A goal with its milestones in order.
class GoalWithMilestones {
  const GoalWithMilestones(this.goal, this.milestones);

  final Goal goal;
  final List<Milestone> milestones;

  int get doneCount => milestones.where((m) => m.done).length;

  /// 0–100: done milestones / total, or 100 once achieved.
  double get percent {
    if (goal.achieved) return 100;
    if (milestones.isEmpty) return 0;
    return doneCount / milestones.length * 100;
  }
}

@DriftAccessor(tables: [Goals, Milestones])
class GoalsDao extends DatabaseAccessor<AppDatabase> with _$GoalsDaoMixin {
  GoalsDao(super.attachedDatabase);

  /// Goals, newest first, with milestones.
  Stream<List<GoalWithMilestones>> watchGoals() => customSelect(
        'SELECT * FROM milestones ORDER BY sort_order',
        readsFrom: {goals, milestones},
      ).watch().asyncMap((rows) async {
        final byGoal = <String, List<Milestone>>{};
        for (final r in rows) {
          final m = milestones.map(r.data);
          (byGoal[m.goalId] ??= <Milestone>[]).add(m);
        }
        final list = await (select(goals)..orderBy([(g) => OrderingTerm.desc(g.createdAt)])).get();
        return [for (final g in list) GoalWithMilestones(g, byGoal[g.id] ?? const <Milestone>[])];
      });

  /// One goal with milestones; null once deleted.
  Stream<GoalWithMilestones?> watchGoal(String id) => watchGoals().map((all) {
        for (final g in all) {
          if (g.goal.id == id) return g;
        }
        return null;
      });

  /// Adds a goal with [milestoneTitles] (in order) and returns its id.
  Future<String> addGoal({
    required String title,
    required GoalCategory category,
    required DateTime targetDate,
    String description = '',
    List<String> milestoneTitles = const [],
  }) =>
      transaction(() async {
        final id = newId();
        await into(goals).insert(GoalsCompanion.insert(
          id: Value(id),
          title: title,
          category: category,
          description: Value(description),
          targetDate: dateOnly(targetDate),
        ));
        for (final (i, t) in milestoneTitles.indexed) {
          await into(milestones).insert(MilestonesCompanion.insert(goalId: id, title: t, sortOrder: Value(i)));
        }
        return id;
      });

  Future<Goal?> goalById(String id) => (select(goals)..where((g) => g.id.equals(id))).getSingleOrNull();

  Future<bool> updateGoal(Goal row) => update(goals).replace(row);

  /// Deletes the goal and its milestones.
  Future<int> deleteGoal(String id) => (delete(goals)..where((g) => g.id.equals(id))).go();

  /// Mark achieved / reopen.
  Future<void> setAchieved(String id, bool achieved) =>
      (update(goals)..where((g) => g.id.equals(id))).write(GoalsCompanion(achieved: Value(achieved)));

  /// Appends a milestone and returns its id.
  Future<String> addMilestone(String goalId, String title) async {
    final next = await customSelect(
      'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next FROM milestones WHERE goal_id = ?1',
      variables: [Variable.withString(goalId)],
      readsFrom: {milestones},
    ).getSingle();
    final id = newId();
    await into(milestones).insert(MilestonesCompanion.insert(id: Value(id), goalId: goalId, title: title, sortOrder: Value(next.read<int>('next'))));
    return id;
  }

  Future<void> setMilestoneDone(String id, bool done) =>
      (update(milestones)..where((m) => m.id.equals(id))).write(MilestonesCompanion(done: Value(done)));

  Future<int> deleteMilestone(String id) => (delete(milestones)..where((m) => m.id.equals(id))).go();
}
