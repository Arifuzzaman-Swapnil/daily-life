// Build step 6.4: which device notifications are planned from reminders,
// events and the Settings toggles; and the app keeps the scheduler in step.
import 'package:dailylife/core/db/app_database.dart';
import 'package:dailylife/core/format/dl_format.dart';
import 'package:dailylife/core/notifications/notification_scheduler.dart';
import 'package:dailylife/core/prefs/notification_prefs.dart';
import 'package:dailylife/core/widgets/dl_widgets.dart';
import 'package:dailylife/features/notifications/notification_planner.dart';
import 'package:dailylife/l10n/app_localizations.dart';
import 'package:dailylife/router.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final now = DateTime(2026, 11, 6, 9, 30); // Friday
  final t = lookupAppLocalizations(const Locale('en'));
  const f = DLFormat(lang: AppLang.en, digits: DigitStyle.en);
  const allOff = NotificationPrefs({
    NotifKind.general: false,
    NotifKind.water: false,
    NotifKind.meal: false,
    NotifKind.office: false,
    NotifKind.calendar: false,
  });
  NotificationPrefs only(Set<NotifKind> on) => NotificationPrefs({for (final k in NotifKind.values) k: on.contains(k)});

  late AppDatabase db;
  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Future<void> reminder(
    String title,
    DateTime date,
    String time, {
    RepeatRule repeat = RepeatRule.once,
    Set<int> days = const {},
    ReminderCategory category = ReminderCategory.personal,
    bool enabled = true,
    bool done = false,
  }) =>
      db.remindersDao.addReminder(RemindersCompanion.insert(
        title: title,
        date: date,
        time: time,
        priority: PriorityLevel.medium,
        category: category,
        repeat: repeat,
        customDays: Value(days),
        enabled: Value(enabled),
        done: Value(done),
      ));

  Future<void> event(String title, DateTime date, {String? start, int remind = 30, RepeatRule repeat = RepeatRule.once}) =>
      db.calendarDao.addEvent(EventsCompanion.insert(
        title: title,
        category: EventCategory.meeting,
        startDate: date,
        endDate: date,
        startTime: Value(start),
        reminderMinutes: Value(remind),
        repeat: repeat,
      ));

  Future<List<PlannedNotification>> plan(NotificationPrefs prefs) async => planNotifications(
        now: now,
        prefs: prefs,
        reminders: await db.remindersDao.activeReminders(),
        events: await db.calendarDao.allEvents(),
        t: t,
        f: f,
      );

  String show(PlannedNotification n) => '${n.title} ${n.at.toIso8601String().substring(0, 16)} ${n.repeat.name}';

  test('reminders: once in the future, daily, weekly, monthly and custom weekdays', () async {
    final today = DateTime(2026, 11, 6);
    await reminder('Medicine', today, '18:00');
    await reminder('Too late', today, '06:00');
    await reminder('Read', DateTime(2026, 11, 1), '22:00', repeat: RepeatRule.daily);
    await reminder('Walk', DateTime(2026, 11, 1), '06:30', repeat: RepeatRule.daily);
    await reminder('Report', DateTime(2026, 10, 30), '09:00', repeat: RepeatRule.weekly);
    await reminder('Internet bill', DateTime(2026, 10, 5), '11:00', repeat: RepeatRule.monthly);
    await reminder('Gym', today, '07:00', repeat: RepeatRule.custom, days: {0, 4}); // Saturday, Wednesday
    await reminder('Off', today, '20:00', enabled: false);
    await reminder('Done', today, '20:00', done: true);

    final p = await plan(only({NotifKind.general}));
    expect(p.map(show), [
      'Medicine 2026-11-06T18:00 none',
      'Read 2026-11-06T22:00 daily',
      'Walk 2026-11-07T06:30 daily',
      'Gym 2026-11-07T07:00 weekly',
      'Gym 2026-11-11T07:00 weekly',
      'Report 2026-11-13T09:00 weekly',
      'Internet bill 2026-12-05T11:00 monthly',
    ]);
    final medicine = p.firstWhere((n) => n.title == 'Medicine');
    expect(medicine.body, '6:00 PM');
    expect(medicine.route, startsWith('/reminders/'));
    expect(medicine.channel, NotifChannel.reminders);
  });

  test('office reminders follow their own toggle; general ones theirs', () async {
    final today = DateTime(2026, 11, 6);
    await reminder('Standup notes', today, '17:00', category: ReminderCategory.office);
    await reminder('Groceries', today, '18:00');
    expect((await plan(only({NotifKind.office}))).map((n) => n.title), ['Standup notes']);
    expect((await plan(only({NotifKind.general}))).map((n) => n.title), ['Groceries']);
    expect(await plan(allOff), isEmpty);
  });

  test('events remind before each occurrence in the next 30 days', () async {
    await event('Demo', DateTime(2026, 11, 8), start: '11:00');
    await event('Standup', DateTime(2026, 11, 6), start: '10:00', remind: 10, repeat: RepeatRule.weekly);
    await event('Bill due', DateTime(2026, 11, 10), remind: 1440, repeat: RepeatRule.monthly); // all day
    await event('No reminder', DateTime(2026, 11, 9), start: '09:00', remind: 0);
    await event('Past', DateTime(2026, 11, 5), start: '09:00');

    final p = await plan(only({NotifKind.calendar}));
    expect(p.where((n) => n.title == 'Demo').map(show), ['Demo 2026-11-08T10:30 none']);
    expect(p.where((n) => n.title == 'Standup').map((n) => n.at.day), [6, 13, 20, 27, 4]);
    expect(p.where((n) => n.title == 'Standup').first.at, DateTime(2026, 11, 6, 9, 50));
    // All-day: relative to 9 AM; the December occurrence is outside the window.
    expect(p.where((n) => n.title == 'Bill due').map(show), ['Bill due 2026-11-09T09:00 none']);
    expect(p.any((n) => n.title == 'No reminder' || n.title == 'Past'), isFalse);
    expect(p.firstWhere((n) => n.title == 'Demo').body, '11:00 AM');
    expect(await plan(only({NotifKind.general})), isEmpty);
  });

  test('water every 2 hours from 8 AM to 10 PM; meals at the usual times', () async {
    final water = await plan(only({NotifKind.water}));
    expect(water, hasLength(8));
    expect(water.every((n) => n.repeat == NotifRepeat.daily && n.channel == NotifChannel.health), isTrue);
    // 8 AM has passed today, so it starts tomorrow; 10 AM is still today.
    expect(water.map((n) => n.at), containsAll([DateTime(2026, 11, 6, 10), DateTime(2026, 11, 6, 22), DateTime(2026, 11, 7, 8)]));
    expect(water.first.body, 'Time for a glass of water');

    final meals = await plan(only({NotifKind.meal}));
    expect(meals.map((n) => n.title), ['Lunch', 'Afternoon snack', 'Dinner', 'Breakfast']);
    expect(meals.first.at, DateTime(2026, 11, 6, 13, 30));
  });

  testWidgets('the app hands the plan to the scheduler and follows the Settings toggles', (tester) async {
    await pumpApp(tester, sampleData: true, size: const Size(393, 2400));
    final notifications = notificationsOf(tester);
    var pending = notifications.pending;
    // Sample data: today's reminders, events, and water (meals are off by default).
    expect(pending.where((n) => n.channel == NotifChannel.health), hasLength(8));
    expect(pending.any((n) => n.title == 'মায়ের ওষুধ কিনুন' && n.at == DateTime(2026, 11, 6, 18)), isTrue);
    expect(pending.any((n) => n.title == 'টিম স্ট্যান্ডআপ' && n.at == DateTime(2026, 11, 6, 9, 50)), isTrue);

    await openRoute(tester, Routes.settings);
    expect(find.text('নোটিফিকেশন'), findsOneWidget);
    await tapOn(tester, find.widgetWithText(DLListRow, 'পানির রিমাইন্ডার'));
    await tapOn(tester, find.widgetWithText(DLListRow, 'খাবারের রিমাইন্ডার'));
    pending = notifications.pending;
    expect(pending.where((n) => n.body == 'পানি পান করার সময় হয়েছে'), isEmpty);
    expect(pending.where((n) => n.channel == NotifChannel.health).map((n) => n.title), ['দুপুরের খাবার', 'বিকালের নাশতা', 'রাতের খাবার', 'সকালের নাশতা']);

    await tapOn(tester, find.widgetWithText(DLListRow, 'ক্যালেন্ডার রিমাইন্ডার'));
    expect(notifications.pending.any((n) => n.route.startsWith('/events/')), isFalse);
  });
}
