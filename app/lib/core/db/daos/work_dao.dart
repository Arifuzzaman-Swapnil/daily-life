import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'work_dao.g.dart';

/// A project with its task counts and logged time.
class ProjectStats {
  const ProjectStats(this.project, {required this.tasks, required this.done, required this.minutes});

  final Project project;
  final int tasks;
  final int done;
  final int minutes;
}

@DriftAccessor(tables: [Projects, Tasks, TimerSessions])
class WorkDao extends DatabaseAccessor<AppDatabase> with _$WorkDaoMixin {
  WorkDao(super.attachedDatabase);

  // ------------------------------------------------------------ projects

  Stream<List<Project>> watchProjects() => (select(projects)..orderBy([(p) => OrderingTerm.asc(p.createdAt)])).watch();

  Stream<List<ProjectStats>> watchProjectStats() => customSelect(
        '''
SELECT p.*, COUNT(t.id) AS n,
       COALESCE(SUM(CASE WHEN t.status = 'done' THEN 1 ELSE 0 END), 0) AS done,
       COALESCE(SUM(t.spent_minutes), 0) AS minutes
  FROM projects p LEFT JOIN tasks t ON t.project_id = p.id
 GROUP BY p.id ORDER BY p.created_at''',
        readsFrom: {projects, tasks},
      ).watch().map((rows) => [
            for (final r in rows)
              ProjectStats(projects.map(r.data), tasks: r.read<int>('n'), done: r.read<int>('done'), minutes: r.read<int>('minutes')),
          ]);

  Future<Project?> projectById(String id) => (select(projects)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<String> addProject(String name, {String description = ''}) async {
    final id = newId();
    await into(projects).insert(ProjectsCompanion.insert(id: Value(id), name: name, description: Value(description)));
    return id;
  }

  Future<bool> updateProject(Project p) => update(projects).replace(p);

  /// Its tasks stay, without a project.
  Future<int> deleteProject(String id) => (delete(projects)..where((p) => p.id.equals(id))).go();

  // ------------------------------------------------------------ tasks

  /// Tasks on [day], by start time.
  Stream<List<Task>> watchTasksOn(DateTime day) => (select(tasks)
        ..where((t) => t.date.equalsValue(dateOnly(day)))
        ..orderBy([(t) => OrderingTerm.asc(t.startTime)]))
      .watch();

  /// Work history: tasks in [range], newest day first and by start time within a
  /// day, optionally for one project and matching [search] in the title.
  Stream<List<Task>> watchTasksIn(DayRange range, {String? projectId, String search = ''}) {
    final q = select(tasks)..where((t) => t.date.isBiggerOrEqualValue(range.start) & t.date.isSmallerThanValue(range.end));
    if (projectId != null) q.where((t) => t.projectId.equals(projectId));
    final s = search.trim();
    if (s.isNotEmpty) q.where((t) => t.title.like('%$s%'));
    q.orderBy([(t) => OrderingTerm.desc(t.date), (t) => OrderingTerm.asc(t.startTime)]);
    return q.watch();
  }

  /// A project's tasks, newest day first.
  Stream<List<Task>> watchProjectTasks(String projectId) => (select(tasks)
        ..where((t) => t.projectId.equals(projectId))
        ..orderBy([(t) => OrderingTerm.desc(t.date), (t) => OrderingTerm.asc(t.startTime)]))
      .watch();

  Future<Task?> taskById(String id) => (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<Task?> watchTask(String id) => (select(tasks)..where((t) => t.id.equals(id))).watchSingleOrNull();

  /// Inserts [row] and returns its id.
  Future<String> addTask(TasksCompanion row) async {
    final id = row.id.present ? row.id.value : newId();
    await into(tasks).insert(row.copyWith(id: Value(id)));
    return id;
  }

  Future<bool> updateTask(Task row) => update(tasks).replace(row);

  Future<int> deleteTask(String id) => (delete(tasks)..where((t) => t.id.equals(id))).go();

  Future<void> setStatus(String id, TaskStatus status) =>
      (update(tasks)..where((t) => t.id.equals(id))).write(TasksCompanion(status: Value(status)));

  /// Adds logged time to a task (the timer's Stop).
  Future<void> addSpentMinutes(String id, int minutes) => (update(tasks)..where((t) => t.id.equals(id)))
      .write(TasksCompanion.custom(spentMinutes: tasks.spentMinutes + Constant(minutes)));

  /// Logged minutes per day (`yyyy-MM-dd`) in [range].
  Stream<Map<String, int>> watchMinutesByDay(DayRange range) => customSelect(
        'SELECT date, SUM(spent_minutes) AS m FROM tasks WHERE date >= ?1 AND date < ?2 GROUP BY date',
        variables: [Variable.withString(range.start), Variable.withString(range.end)],
        readsFrom: {tasks},
      ).watch().map((rows) => {for (final r in rows) r.read<String>('date'): r.read<int>('m')});

  // ------------------------------------------------------------ timer

  /// The single persisted timer (the start/pause/stop rules live in the Work feature).
  Stream<TimerSession> watchTimer() => (select(timerSessions)..where((t) => t.id.equals(1))).watchSingle();

  Future<TimerSession> timer() => (select(timerSessions)..where((t) => t.id.equals(1))).getSingle();

  Future<void> saveTimer(TimerSessionsCompanion changes) =>
      (update(timerSessions)..where((t) => t.id.equals(1))).write(changes);
}
