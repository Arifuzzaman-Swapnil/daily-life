// Build step 6.5: personal goals (prototype `goals`, `goalDetail`, `goalForm`;
// screenshots 63–65) on the sample data in Bengali with the pinned clock
// (Friday 2026-11-06).
import 'package:dailylife/core/db/app_database.dart';
import 'package:dailylife/core/widgets/dl_widgets.dart';
import 'package:dailylife/features/goals/goals_screen.dart';
import 'package:dailylife/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('goals: Active / Achieved with counts, categories, progress (screen 63)', (tester) async {
    await pumpApp(tester, sampleData: true, size: const Size(393, 2400));
    await openRoute(tester, Routes.goals);
    expect(titleBar('ব্যক্তিগত লক্ষ্য'), findsOneWidget);
    expect(find.text('চলমান (৪)'), findsOneWidget);
    expect(find.text('অর্জিত (১)'), findsOneWidget);
    expect(find.text('মা-বাবাকে নিয়ে ভ্রমণ'), findsNothing);

    await tapOn(tester, find.widgetWithText(DLChip, 'শেখা'));
    expect(find.text('AWS সার্টিফিকেশন'), findsOneWidget);
    expect(find.text('সিনিয়র ইঞ্জিনিয়ার পদ'), findsNothing);
    expect(find.text('৫০%'), findsOneWidget);
    expect(find.text('২/৪ মাইলফলক'), findsOneWidget);
    expect(find.text('১১৪ দিন বাকি'), findsOneWidget);

    await tapOn(tester, find.widgetWithText(DLChip, 'সব'));
    await tapOn(tester, find.text('অর্জিত (১)'));
    expect(find.text('মা-বাবাকে নিয়ে ভ্রমণ'), findsOneWidget);
    expect(find.text('১০০%'), findsOneWidget);

    await tapOn(tester, find.widgetWithText(DLChip, 'আর্থিক'));
    expect(find.text('এখানে কোনো লক্ষ্য নেই'), findsOneWidget);
  });

  testWidgets('goal details: milestones, add one, achieve / reopen, delete (screen 64)', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: const Size(393, 2400));
    await openRoute(tester, Routes.goal('gl1'));
    expect(titleBar('লক্ষ্যের বিবরণ'), findsOneWidget);
    expect(find.text('AWS সার্টিফিকেশন'), findsOneWidget);
    expect(find.text('৫০%'), findsOneWidget);
    expect(find.text('লক্ষ্যের তারিখ: ২৮ ফেব্রু ২০২৭ · চলমান'), findsOneWidget);
    expect(find.text('২/৪ মাইলফলক'), findsOneWidget);

    final milestones = await (db.select(db.milestones)..where((m) => m.goalId.equals('gl1'))).get();
    final open = milestones.firstWhere((m) => !m.done);
    await tapOn(tester, find.text(open.title));
    expect(find.text('অগ্রগতি হালনাগাদ হয়েছে'), findsOneWidget);
    expect(find.text('৩/৪ মাইলফলক'), findsOneWidget);
    expect(find.text('৭৫%'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'মক পরীক্ষা');
    await tapOn(tester, find.widgetWithText(DLButton, 'যোগ করুন'));
    expect(find.text('মক পরীক্ষা'), findsOneWidget);
    expect(find.text('৩/৫ মাইলফলক'), findsOneWidget);

    await tapOn(tester, find.text('অর্জিত হিসেবে চিহ্নিত করুন'));
    expect(find.text('অভিনন্দন! লক্ষ্য অর্জিত হয়েছে'), findsNWidgets(2)); // toast and note
    expect(find.text('১০০%'), findsOneWidget);
    expect((await db.goalsDao.goalById('gl1'))!.achieved, isTrue);
    await tapOn(tester, find.text('আবার চালু করুন'));
    expect((await db.goalsDao.goalById('gl1'))!.achieved, isFalse);

    await tapOn(tester, find.byTooltip('মুছে ফেলুন'));
    expect(find.text('মুছে ফেলুন?'), findsOneWidget);
    await tapOn(tester, find.descendant(of: find.byType(DLConfirmDialog), matching: find.text('মুছে ফেলুন')));
    expect(await db.goalsDao.goalById('gl1'), isNull);
  });

  testWidgets('new goal with milestones opens its details; edit keeps them (screen 65)', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: const Size(393, 2400));
    await openRoute(tester, Routes.goals);
    await tapOn(tester, find.byTooltip('নতুন লক্ষ্য'));
    expect(titleBar('নতুন লক্ষ্য'), findsOneWidget);
    expect(find.text('৩১ ডিসে ২০২৬'), findsOneWidget);

    await tapOn(tester, find.text('সংরক্ষণ করুন'));
    expect(find.text('একটি নাম লিখুন'), findsOneWidget);
    await typeInto(tester, 'শিরোনাম', 'জরুরি তহবিল');
    await tapOn(tester, find.widgetWithText(DLChip, 'আর্থিক'));
    await typeInto(tester, 'মাইলফলক (ঐচ্ছিক)', 'প্রথম ১০ হাজার\n\nদ্বিতীয় ১০ হাজার\nশেষ ১০ হাজার');
    await tapOn(tester, find.text('সংরক্ষণ করুন'));

    expect(find.text('লক্ষ্য যোগ হয়েছে'), findsOneWidget);
    expect(titleBar('লক্ষ্যের বিবরণ'), findsOneWidget);
    expect(find.text('জরুরি তহবিল'), findsOneWidget);
    expect(find.text('০/৩ মাইলফলক'), findsOneWidget);
    expect(find.text('দ্বিতীয় ১০ হাজার'), findsOneWidget);
    final g = (await db.select(db.goals).get()).singleWhere((g) => g.title == 'জরুরি তহবিল');
    expect((g.category, dayKey(g.targetDate)), (GoalCategory.financial, '2026-12-31'));

    await tapOn(tester, find.widgetWithText(DLButton, 'সম্পাদনা করুন'));
    expect(titleBar('সম্পাদনা করুন'), findsOneWidget);
    expect(find.text('মাইলফলক (ঐচ্ছিক)'), findsNothing); // milestones are edited on the goal itself
    await typeInto(tester, 'শিরোনাম', 'জরুরি তহবিল ২০২৭');
    await tapOn(tester, find.text('সংরক্ষণ করুন'));
    expect(find.text('জরুরি তহবিল ২০২৭'), findsOneWidget);
    expect(find.text('০/৩ মাইলফলক'), findsOneWidget);
    expect(find.byType(GoalDetailScreen), findsOneWidget);
  });

  testWidgets('no goals: empty state with an action', (tester) async {
    await pumpApp(tester, size: const Size(393, 1800));
    await openRoute(tester, Routes.goals);
    expect(find.text('এখানে কোনো লক্ষ্য নেই'), findsOneWidget);
    expect(find.text('চলমান (০)'), findsOneWidget);
    await tapOn(tester, find.widgetWithText(DLButton, 'নতুন লক্ষ্য'));
    expect(titleBar('নতুন লক্ষ্য'), findsOneWidget);
  });
}
