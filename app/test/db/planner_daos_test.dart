import 'package:dailylife/core/db/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

final today = DateTime(2026, 11, 6);

void main() {
  late AppDatabase db;
  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  test('work: tasks by day, status, logged time and project stats', () async {
    final dao = db.workDao;
    final p = await dao.addProject('Baselinq');
    TasksCompanion task(String title, String start, DateTime date, {TaskStatus status = TaskStatus.todo}) => TasksCompanion.insert(
          title: title,
          projectId: Value(p),
          date: date,
          startTime: start,
          endTime: '18:00',
          status: status,
          priority: PriorityLevel.medium,
        );
    final b = await dao.addTask(task('B', '11:30', today));
    final a = await dao.addTask(task('A', '09:30', today, status: TaskStatus.done));
    await dao.addTask(task('C', '10:00', DateTime(2026, 11, 5)));

    expect((await dao.watchTasksOn(today).first).map((t) => t.title), ['A', 'B']);
    final history = await dao.watchTasksIn(DayRange(DateTime(2026, 11, 1), DateTime(2026, 11, 8)), search: 'b').first;
    expect(history.map((t) => t.title), ['B']);

    await dao.setStatus(b, TaskStatus.inProgress);
    await dao.addSpentMinutes(b, 45);
    await dao.addSpentMinutes(b, 15);
    final row = (await dao.taskById(b))!;
    expect((row.status, row.spentMinutes), (TaskStatus.inProgress, 60));

    final stats = (await dao.watchProjectStats().first).single;
    expect((stats.tasks, stats.done, stats.minutes), (3, 1, 60));
    expect(await dao.watchMinutesByDay(DayRange.day(today)).first, {'2026-11-06': 60});

    // The timer row survives and points at a task until that task is deleted.
    await dao.saveTimer(TimerSessionsCompanion(taskId: Value(a), state: const Value(TimerState.paused), accumulatedMs: const Value(90000)));
    expect((await dao.timer()).accumulatedMs, 90000);
    await dao.deleteTask(a);
    expect((await dao.timer()).taskId, isNull);
  });

  test('reminders: today (with overdue), upcoming, completed, snooze', () async {
    final dao = db.remindersDao;
    RemindersCompanion rem(String title, DateTime date, String time, {bool done = false}) => RemindersCompanion.insert(
          title: title,
          date: date,
          time: time,
          priority: PriorityLevel.medium,
          category: ReminderCategory.personal,
          repeat: RepeatRule.once,
          done: Value(done),
        );
    final lateNight = await dao.addReminder(rem('Late night', today, '23:55'));
    await dao.addReminder(rem('Overdue', DateTime(2026, 11, 4), '09:00'));
    await dao.addReminder(rem('Tomorrow', DateTime(2026, 11, 7), '10:00'));
    await dao.addReminder(rem('Done', today, '06:30', done: true));

    expect((await dao.watchToday(today).first).map((r) => r.title), ['Overdue', 'Late night']);
    expect((await dao.watchUpcoming(today).first).map((r) => r.title), ['Tomorrow']);
    expect((await dao.watchCompleted().first).map((r) => r.title), ['Done']);
    expect(await dao.watchCounts(today).first, (today: 2, upcoming: 1, completed: 1));

    await dao.snooze(lateNight);
    expect((await dao.reminderById(lateNight))!.time, '00:05');
    await dao.setDone(lateNight, true);
    await dao.setEnabled(lateNight, false);
    final r = (await dao.reminderById(lateNight))!;
    expect((r.done, r.enabled), (true, false));
  });

  test('notes: pinned first, archive, search, edit stamps updatedAt', () async {
    final dao = db.notesDao;
    final a = await dao.addNote(NotesCompanion.insert(category: NoteCategory.personal, title: const Value('Budget'), updatedAt: Value(DateTime(2026, 11, 1))));
    final b = await dao.addNote(NotesCompanion.insert(category: NoteCategory.ideas, title: const Value('Idea'), body: const Value('SMS reminders'), updatedAt: Value(DateTime(2026, 11, 2))));
    expect((await dao.watchNotes().first).map((n) => n.id), [b, a]);

    await dao.setPinned(a, true);
    expect((await dao.watchNotes().first).map((n) => n.id), [a, b]);
    expect((await dao.watchNotes(search: 'sms').first).single.id, b);
    expect((await dao.watchNotes(category: NoteCategory.ideas).first).single.id, b);

    await dao.setArchived(b, true);
    expect((await dao.watchNotes().first).map((n) => n.id), [a]);
    expect((await dao.watchNotes(archived: true).first).single.id, b);
    expect(await dao.watchActiveCount().first, 1);

    final note = (await dao.noteById(a))!;
    await dao.updateNote(note.copyWith(body: 'Rent 10,000'), now: DateTime(2026, 11, 6, 9));
    final edited = (await dao.noteById(a))!;
    expect(edited.body, 'Rent 10,000');
    expect(edited.updatedAt.isAtSameMomentAs(DateTime(2026, 11, 6, 9)), isTrue);
  });

  test('health: water totals, meals and habit checks', () async {
    final dao = db.healthDao;
    await dao.addWater(date: today, time: '07:30', ml: 250);
    await dao.addWater(date: today, time: '09:15', ml: 500);
    await dao.addWater(date: DateTime(2026, 11, 5), time: '12:00', ml: 3000);
    expect((await dao.watchWaterOn(today).first).map((w) => w.time), ['09:15', '07:30']);
    expect(await dao.watchWaterTotals(DayRange.lastDays(today, 7)).first, {'2026-11-05': 3000, '2026-11-06': 750});

    await dao.addMeal(MealsCompanion.insert(type: MealType.lunch, date: today, time: '13:30', description: const Value('Rice')));
    await dao.addMeal(MealsCompanion.insert(type: MealType.breakfast, date: today, time: '08:00'));
    expect((await dao.watchMealsOn(today).first).map((m) => m.type), [MealType.breakfast, MealType.lunch]);

    final h = await dao.addHabit(name: 'Reading', icon: 'book', reminderTime: '22:00');
    expect(await dao.toggle(h, today), isTrue);
    await dao.setDone(h, DateTime(2026, 11, 5), true);
    await dao.setDone(h, DateTime(2026, 11, 5), true); // idempotent
    var habit = (await dao.watchHabits().first).single;
    expect(habit.dayKeys, {'2026-11-05', '2026-11-06'});
    expect(habit.isDoneOn(today), isTrue);
    expect(await dao.toggle(h, today), isFalse);
    habit = (await dao.watchHabits().first).single;
    expect(habit.isDoneOn(today), isFalse);
  });

  test('goals: progress from milestones, 100 % once achieved', () async {
    final dao = db.goalsDao;
    final id = await dao.addGoal(title: 'AWS', category: GoalCategory.learning, targetDate: DateTime(2027, 2, 28), milestoneTitles: ['Course', 'Mocks', 'Book', 'Pass']);
    var g = (await dao.watchGoal(id).first)!;
    expect(g.milestones.map((m) => m.title), ['Course', 'Mocks', 'Book', 'Pass']);
    expect(g.percent, 0);

    await dao.setMilestoneDone(g.milestones[0].id, true);
    await dao.setMilestoneDone(g.milestones[1].id, true);
    await dao.addMilestone(id, 'Celebrate');
    g = (await dao.watchGoal(id).first)!;
    expect((g.doneCount, g.milestones.length, g.percent), (2, 5, 40));

    await dao.setAchieved(id, true);
    expect((await dao.watchGoal(id).first)!.percent, 100);
    await dao.setAchieved(id, false);
    expect((await dao.watchGoal(id).first)!.percent, 40);
  });

  test('calendar, documents and inbox CRUD', () async {
    final ev = await db.calendarDao.addEvent(EventsCompanion.insert(
      title: 'Standup',
      category: EventCategory.meeting,
      startDate: today,
      endDate: today,
      startTime: const Value('10:00'),
      endTime: const Value('10:30'),
      repeat: RepeatRule.weekly,
      reminderMinutes: const Value(10),
    ));
    await db.calendarDao.addEvent(EventsCompanion.insert(title: 'Payday', category: EventCategory.important, startDate: today, endDate: today, repeat: RepeatRule.monthly));
    expect((await db.calendarDao.watchEvents().first).map((e) => e.title), ['Payday', 'Standup']);
    await db.calendarDao.deleteEvent(ev);
    expect(await db.calendarDao.eventById(ev), isNull);

    await db.documentsDao.addDocument(DocumentsCompanion.insert(title: 'Offer letter', category: DocCategory.office, kind: DocKind.pdf, sizeBytes: const Value(245760)));
    await db.documentsDao.addDocument(DocumentsCompanion.insert(title: 'Photo', category: DocCategory.personal, kind: DocKind.img));
    expect(await db.documentsDao.watchCounts().first, {DocCategory.office: 1, DocCategory.personal: 1});
    expect((await db.documentsDao.watchDocuments(search: 'offer').first).single.sizeBytes, 245760);

    final n = await db.inboxDao.addItem(icon: 'bell', tone: 'warning', title: 'Buy medicine', route: 'reminders');
    await db.inboxDao.addItem(icon: 'drop', tone: 'accent', title: 'Water');
    expect(await db.inboxDao.watchUnreadCount().first, 2);
    await db.inboxDao.markRead(n);
    expect(await db.inboxDao.watchUnreadCount().first, 1);
    await db.inboxDao.markAllRead();
    expect(await db.inboxDao.watchUnreadCount().first, 0);
  });
}
