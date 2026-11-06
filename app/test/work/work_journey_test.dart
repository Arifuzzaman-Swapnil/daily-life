// Acceptance journey 6 from the brief: Work → Add task → Start timer → Pause →
// Resume → Stop (time logged) → Mark complete. A test clock stands in for the
// device clock so the logged time is exact.
import 'package:dailylife/core/db/app_database.dart';
import 'package:dailylife/core/widgets/dl_widgets.dart';
import 'package:dailylife/features/work/work_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('journey 6: add a task, time it (start, pause, resume, stop), mark it complete', (tester) async {
    final clock = TestClock();
    final db = await pumpApp(tester, sampleData: true, size: kTallPhone, clock: clock.call);

    await tester.tap(navLabel('কাজ'));
    await tester.pumpAndSettle();
    await tapOn(tester, find.byTooltip('কাজ যোগ করুন'));
    await typeInto(tester, 'কাজের নাম', 'রিলিজ নোট লেখা');
    await tapOn(tester, find.widgetWithText(DLChip, 'Truckwise'));
    await tapOn(tester, find.text('সংরক্ষণ করুন'));
    expect(find.text('কাজ সংরক্ষণ হয়েছে'), findsOneWidget);

    final task = (await db.workDao.watchTasksOn(DateTime(2026, 11, 6)).first).singleWhere((k) => k.title == 'রিলিজ নোট লেখা');
    expect(task.status, TaskStatus.todo);

    // Task details → Start timer: the timer opens on this task.
    await tapOn(tester, find.descendant(of: find.byType(TaskCard), matching: find.text('রিলিজ নোট লেখা')));
    expect(titleBar('কাজের বিবরণ'), findsOneWidget);
    await tapOn(tester, find.text('টাইমার চালু করুন'));
    expect(titleBar('ওয়ার্ক টাইমার'), findsOneWidget);
    expect(find.text('প্রস্তুত'), findsOneWidget);
    expect(find.text('রিলিজ নোট লেখা · Truckwise'), findsOneWidget);
    expect(tester.widget<DLChip>(find.widgetWithText(DLChip, 'রিলিজ নোট লেখা')).selected, isTrue);

    // Start: running, and the not-started task moves to in progress.
    await tapOn(tester, find.text('শুরু করুন'));
    expect(find.text('চলছে'), findsOneWidget);
    expect((await db.workDao.taskById(task.id))!.status, TaskStatus.inProgress);
    // The task can't change while the timer runs.
    expect(tester.widget<DLChip>(find.widgetWithText(DLChip, 'বিলিং ইন্টিগ্রেশন')).onTap, isNull);
    expect((await db.workDao.timer()).taskId, task.id);

    clock.advance(const Duration(minutes: 25));
    await tapOn(tester, find.text('বিরতি দিন'));
    expect(find.text('বিরতিতে'), findsOneWidget);
    expect(find.text('০০:২৫:০০'), findsOneWidget);

    // Paused time doesn't count.
    clock.advance(const Duration(minutes: 10));
    await tapOn(tester, find.text('আবার শুরু করুন'));
    expect(find.text('চলছে'), findsOneWidget);

    clock.advance(const Duration(minutes: 20, seconds: 20));
    await tapOn(tester, find.text('থামান ও সংরক্ষণ করুন'));
    expect(find.text('সংরক্ষিত'), findsOneWidget);
    expect(find.text('০০:৪৫:২০'), findsOneWidget);
    // Toast and the saved banner.
    expect(find.text('৪৫ মি সময় যোগ হয়েছে'), findsNWidgets(2));
    expect((await db.workDao.taskById(task.id))!.spentMinutes, 45);

    await tapOn(tester, find.text('সম্পন্ন করুন'));
    expect(find.text('কাজ সম্পন্ন হয়েছে'), findsOneWidget);
    expect((await db.workDao.taskById(task.id))!.status, TaskStatus.done);
    final timer = await db.workDao.timer();
    expect((timer.state, timer.accumulatedMs), (TimerState.idle, 0));

    // Back on Work: the hours include the logged 45 minutes (2 h 15 m + 45 m).
    await tapOn(tester, find.byTooltip('পেছনে যান'));
    await tapOn(tester, find.byTooltip('পেছনে যান'));
    expect(titleBar('অফিস ও কাজ'), findsOneWidget);
    expect(find.text('৩ ঘ'), findsOneWidget);
  });

  testWidgets('a stop under half a minute still logs 1 minute', (tester) async {
    final clock = TestClock();
    final db = await pumpApp(tester, sampleData: true, size: kTallPhone, clock: clock.call);
    await tester.tap(navLabel('কাজ'));
    await tester.pumpAndSettle();
    await tapOn(tester, find.byType(DLHero));
    expect(titleBar('ওয়ার্ক টাইমার'), findsOneWidget);
    await tapOn(tester, find.text('শুরু করুন'));
    clock.advance(const Duration(seconds: 10));
    await tapOn(tester, find.text('থামান ও সংরক্ষণ করুন'));
    expect(find.text('১ মি সময় যোগ হয়েছে'), findsNWidgets(2));
    // The sample timer is on k2 (45 minutes logged before).
    expect((await db.workDao.taskById('k2'))!.spentMinutes, 46);
  });
}
