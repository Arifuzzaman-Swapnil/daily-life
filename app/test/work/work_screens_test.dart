// Build step 6.1: the Work tab, task form and detail, work history, projects
// (prototype `work` … `projectDetail`, screenshots 30–38 and 92) on the sample
// data in Bengali, with the pinned clock (Friday 2026-11-06 09:30).
import 'package:dailylife/core/db/app_database.dart';
import 'package:dailylife/core/widgets/dl_widgets.dart';
import 'package:dailylife/features/work/work_providers.dart';
import 'package:dailylife/features/work/work_screen.dart';
import 'package:dailylife/features/work/work_ui.dart';
import 'package:dailylife/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

Future<void> openWork(WidgetTester tester) async {
  await tester.tap(navLabel('কাজ'));
  await tester.pumpAndSettle();
  expect(titleBar('অফিস ও কাজ'), findsOneWidget);
}

/// The stat card whose label is [label].
Finder stat(String label) => find.ancestor(of: find.text(label), matching: find.byType(DLCard)).first;

void main() {
  testWidgets('Work tab: today\'s figures, the timer, the week and today\'s tasks (screen 30)', (tester) async {
    await pumpApp(tester, sampleData: true, size: kTallPhone);
    await openWork(tester);
    expect(find.byType(WorkScreen), findsOneWidget);
    expect(find.text('৬ নভেম্বর, শুক্রবার'), findsOneWidget);

    for (final (label, value) in [
      ('আজকের কাজ', '৪'),
      ('সম্পন্ন', '১'),
      ('চলমান / বাকি', '১/২'),
      ('কাজের সময়', '২ ঘ ১৫ মি'),
    ]) {
      expect(find.descendant(of: stat(label), matching: find.text(value)), findsOneWidget, reason: label);
    }

    // The timer hero: idle on the sample's task.
    final hero = find.byType(DLHero);
    expect(find.descendant(of: hero, matching: find.text('টাইমার চালু করুন')), findsOneWidget);
    expect(find.descendant(of: hero, matching: find.text('০০:০০:০০')), findsOneWidget);
    expect(find.descendant(of: hero, matching: find.text('রোল-ভিত্তিক পারমিশন টেস্ট · Baselinq')), findsOneWidget);

    // This week, Saturday to Friday; today highlighted.
    expect(find.text('২৮ ঘ ৪৫ মি'), findsOneWidget);
    final chart = tester.widget<DLBarChart>(find.byType(DLBarChart));
    expect([for (final g in chart.groups) g.label], ['শনি', 'রবি', 'সোম', 'মঙ্গল', 'বুধ', 'বৃহঃ', 'শুক্র']);
    expect([for (final g in chart.groups) g.valueLabel], ['', '', '৭.৫', '৬.৫', '৬', '৬.৫', '২.৩']);
    expect(chart.selectedIndex, 6);

    // Today's tasks by start time, with project, status and time.
    expect([for (final c in tester.widgetList<TaskCard>(find.byType(TaskCard))) c.task.id], ['k1', 'k2', 'k3', 'k4']);
    expect(find.descendant(of: find.byType(TaskCard).at(2), matching: find.text('Truckwise')), findsOneWidget);
    expect(find.descendant(of: find.byType(TaskCard).at(2), matching: find.text('শুরু হয়নি')), findsOneWidget);
    expect(find.descendant(of: find.byType(TaskCard).at(2), matching: find.text('দুপুর ২:০০ – বিকাল ৪:০০')), findsOneWidget);
  });

  testWidgets('ticking a task marks it done (toast) and unticking reopens it', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTallPhone);
    await openWork(tester);
    await tapOn(tester, find.descendant(of: find.byType(TaskCard).at(1), matching: find.byType(DLCheckbox)));
    expect(find.text('কাজ সম্পন্ন হয়েছে'), findsOneWidget);
    expect((await db.workDao.taskById('k2'))!.status, TaskStatus.done);
    expect(find.descendant(of: stat('সম্পন্ন'), matching: find.text('২')), findsOneWidget);

    await tapOn(tester, find.descendant(of: find.byType(TaskCard).at(1), matching: find.byType(DLCheckbox)));
    expect((await db.workDao.taskById('k2'))!.status, TaskStatus.todo);
  });

  testWidgets('add work validates the name, project and times (screen 31)', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTallPhone);
    await openWork(tester);
    await tapOn(tester, find.byTooltip('কাজ যোগ করুন'));
    expect(titleBar('কাজ যোগ করুন'), findsOneWidget);
    // A new task starts in the first project, today, 10:00–11:00 (1 h).
    expect(tester.widget<DLChip>(find.widgetWithText(DLChip, 'Baselinq')).selected, isTrue);
    expect(find.text('১ ঘ'), findsOneWidget);

    await tapOn(tester, find.text('সংরক্ষণ করুন'));
    expect(find.text('একটি নাম লিখুন'), findsOneWidget);
    expect(find.text('লাল চিহ্নিত ঘরগুলো ঠিক করুন'), findsOneWidget);

    await typeInto(tester, 'কাজের নাম', 'API ডকুমেন্টেশন');
    expect(find.text('একটি নাম লিখুন'), findsNothing);
    await tapOn(tester, find.widgetWithText(DLChip, 'Hitec'));
    await tapOn(tester, find.widgetWithText(DLChip, 'উচ্চ'));
    await tapOn(tester, find.text('সংরক্ষণ করুন'));

    expect(find.text('কাজ সংরক্ষণ হয়েছে'), findsOneWidget);
    expect(titleBar('অফিস ও কাজ'), findsOneWidget);
    final saved = (await db.workDao.watchTasksOn(DateTime(2026, 11, 6)).first).firstWhere((k) => k.title == 'API ডকুমেন্টেশন');
    expect((saved.projectId, saved.priority, saved.status, saved.startTime, saved.endTime), ('p3', PriorityLevel.high, TaskStatus.todo, '10:00', '11:00'));
    expect([for (final c in tester.widgetList<TaskCard>(find.byType(TaskCard))) c.task.title][1], 'API ডকুমেন্টেশন');
  });

  testWidgets('a new project from the task form is created and selected', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTallPhone);
    await openRoute(tester, Routes.newTask());
    await tapOn(tester, find.widgetWithText(DLChip, 'নতুন প্রজেক্ট'));
    expect(find.byType(DLSheet), findsOneWidget);
    await tapOn(tester, find.descendant(of: find.byType(DLSheet), matching: find.text('যোগ করুন')));
    expect(find.text('একটি নাম লিখুন'), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byType(DLSheet), matching: find.byType(EditableText)), 'Intelleqt');
    await tapOn(tester, find.descendant(of: find.byType(DLSheet), matching: find.text('যোগ করুন')));

    expect(find.byType(DLSheet), findsNothing);
    expect(find.text('প্রজেক্ট যোগ হয়েছে'), findsOneWidget);
    expect(tester.widget<DLChip>(find.widgetWithText(DLChip, 'Intelleqt')).selected, isTrue);
    expect((await db.workDao.watchProjects().first).map((p) => p.name), contains('Intelleqt'));
  });

  testWidgets('task detail: status chips, facts, edit and delete (screen 32)', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTallPhone);
    await openRoute(tester, Routes.task('k2'));
    expect(titleBar('কাজের বিবরণ'), findsOneWidget);
    for (final (k, v) in [
      ('তারিখ', '৬ নভেম্বর, শুক্রবার'),
      ('সময়', 'সকাল ১১:৩০ – দুপুর ১:০০'),
      ('সময়কাল', '১ ঘ ৩০ মি'),
      ('ব্যয়িত সময়', '৪৫ মি'),
      ('অবস্থা', 'চলমান'),
    ]) {
      expect(find.widgetWithText(DLKeyValueRow, v), findsOneWidget, reason: k);
    }
    expect(find.text('উচ্চ'), findsOneWidget);

    await tapOn(tester, find.widgetWithText(DLChip, 'স্থগিত'));
    expect((await db.workDao.taskById('k2'))!.status, TaskStatus.onHold);
    await tapOn(tester, find.text('সম্পন্ন করুন'));
    expect(find.text('কাজ সম্পন্ন হয়েছে'), findsOneWidget);
    expect((await db.workDao.taskById('k2'))!.status, TaskStatus.done);

    // Edit keeps the values and saves changes.
    await tapOn(tester, find.byTooltip('সম্পাদনা করুন'));
    expect(titleBar('কাজ সম্পাদনা'), findsOneWidget);
    await typeInto(tester, 'কাজের নাম', 'পারমিশন টেস্ট শেষ');
    await tapOn(tester, find.text('সংরক্ষণ করুন'));
    expect(titleBar('কাজের বিবরণ'), findsOneWidget);
    expect(find.text('পারমিশন টেস্ট শেষ'), findsOneWidget);
    expect((await db.workDao.taskById('k2'))!.spentMinutes, 45);

    // Delete asks first.
    await tapOn(tester, find.byTooltip('মুছে ফেলুন'));
    expect(find.text('কাজটি মুছে ফেলবেন?'), findsOneWidget);
    await tapOn(tester, find.descendant(of: find.byType(DLConfirmDialog), matching: find.text('মুছে ফেলুন')));
    expect(find.text('কাজ মুছে ফেলা হয়েছে'), findsOneWidget);
    expect(await db.workDao.taskById('k2'), isNull);
  });

  testWidgets('work history: weekly totals and timeline; daily, project and search filters (screen 36)', (tester) async {
    await pumpApp(tester, sampleData: true, size: const Size(393, 3000));
    await openRoute(tester, Routes.workHistory);
    expect(titleBar('কাজের ইতিহাস'), findsOneWidget);
    expect(find.text('২৮ ঘ ৪৫ মি'), findsOneWidget);
    expect(find.text('৭'), findsOneWidget);
    expect(find.text('১১'), findsOneWidget);
    expect(find.byType(TimelineTaskCard), findsNWidgets(11));
    // Newest day first: tomorrow's demo prep heads the list.
    expect(find.text('৭ নভেম্বর, শনিবার'), findsOneWidget);
    expect(tester.widget<TimelineTaskCard>(find.byType(TimelineTaskCard).first).task.id, 'k11');

    await tapOn(tester, find.text('দৈনিক'));
    expect(find.byType(TimelineTaskCard), findsNWidgets(5));

    await tapOn(tester, find.text('মাসিক'));
    await tapOn(tester, find.widgetWithText(DLChip, 'Truckwise'));
    expect(find.byType(TimelineTaskCard), findsNWidgets(3));

    await tester.enterText(find.descendant(of: find.byType(DLSearchBar), matching: find.byType(EditableText)), 'কোড');
    await tester.pumpAndSettle();
    expect(find.byType(TimelineTaskCard), findsOneWidget);

    await tester.enterText(find.descendant(of: find.byType(DLSearchBar), matching: find.byType(EditableText)), 'নেই এমন');
    await tester.pumpAndSettle();
    expect(find.text('এই সময়ে কোনো কাজ নেই'), findsOneWidget);
    expect(containerOf(tester).read(workHistoryFilterProvider).projectId, 'p2');
  });

  testWidgets('projects and a project\'s detail (screens 37–38)', (tester) async {
    await pumpApp(tester, sampleData: true, size: kTallPhone);
    await openRoute(tester, Routes.projects);
    expect(titleBar('প্রজেক্ট'), findsOneWidget);
    expect(find.text('৬টি কাজ · ৪টি সম্পন্ন'), findsOneWidget);
    expect(find.text('১৩ ঘ ৪৫ মি'), findsOneWidget);

    await tapOn(tester, find.text('Baselinq'));
    expect(titleBar('Baselinq'), findsOneWidget);
    final hero = find.byType(DLHero);
    expect(find.descendant(of: hero, matching: find.text('নির্মাণ প্রকল্প ব্যবস্থাপনা প্ল্যাটফর্ম')), findsOneWidget);
    for (final v in ['১৩ ঘ ৪৫ মি', '৪/৬', '৬৭%']) {
      expect(find.descendant(of: hero, matching: find.text(v)), findsOneWidget, reason: v);
    }
    expect(find.byType(DLListRow), findsNWidgets(6));
    expect(find.text('৬ নভে ২০২৬ · ১ ঘ ৩০ মি'), findsOneWidget);

    // "Add" starts a task in this project.
    await tapOn(tester, find.widgetWithText(DLLinkButton, 'যোগ করুন'));
    expect(titleBar('কাজ যোগ করুন'), findsOneWidget);
    expect(tester.widget<DLChip>(find.widgetWithText(DLChip, 'Baselinq')).selected, isTrue);
  });

  testWidgets('empty Work tab, history and projects (screen 92)', (tester) async {
    await pumpApp(tester, size: kTallPhone);
    await openWork(tester);
    expect(find.text('আজকের জন্য কোনো কাজ নেই।'), findsOneWidget);
    expect(find.text('নতুন কাজ যোগ করে দিনটি গুছিয়ে নিন।'), findsOneWidget);
    expect(find.descendant(of: stat('কাজের সময়'), matching: find.text('০ মি')), findsOneWidget);
    expect(find.descendant(of: find.byType(DLHero), matching: find.text('কাজ বেছে নিন')), findsOneWidget);

    await tapOn(tester, find.widgetWithText(DLButton, 'কাজ যোগ করুন'));
    expect(titleBar('কাজ যোগ করুন'), findsOneWidget);
    // No project yet: choosing one is required.
    await typeInto(tester, 'কাজের নাম', 'প্রথম কাজ');
    await tapOn(tester, find.text('সংরক্ষণ করুন'));
    expect(find.text('একটি ক্যাটাগরি বেছে নিন'), findsOneWidget);

    await openRoute(tester, Routes.workHistory);
    expect(find.text('এই সময়ে কোনো কাজ নেই'), findsOneWidget);
    await openRoute(tester, Routes.projects);
    expect(find.text('এখনো কোনো প্রজেক্ট নেই'), findsOneWidget);
  });
}
