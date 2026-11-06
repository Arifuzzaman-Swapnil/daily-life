// Build step 6.5: Health & habits (prototype `health`, `mealForm`,
// `habitDetail`; screenshots 58–62) on the sample data in Bengali with the
// pinned clock (Friday 2026-11-06 09:30).
import 'package:dailylife/core/db/app_database.dart';
import 'package:dailylife/core/prefs/health_prefs.dart';
import 'package:dailylife/core/prefs/notification_prefs.dart';
import 'package:dailylife/core/widgets/dl_widgets.dart';
import 'package:dailylife/features/health/health_providers.dart';
import 'package:dailylife/features/health/health_screen.dart';
import 'package:dailylife/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

const kTall = Size(393, 2400);

Future<int> waterToday(AppDatabase db) async =>
    (await db.select(db.waterEntries).get()).where((w) => dayKey(w.date) == '2026-11-06').fold<int>(0, (a, w) => a + w.ml);

void main() {
  testWidgets('water: ring, figures, quick add, custom amount, target, log (screen 58)', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTall);
    await openRoute(tester, Routes.healthTab(HealthTab.water));
    expect(titleBar('স্বাস্থ্য ও অভ্যাস'), findsOneWidget);
    expect(find.text('৫০%'), findsOneWidget);
    expect(find.text('১,৫০০ মিলি'), findsNWidgets(3)); // ring, consumed, remaining
    expect(find.text('৩,০০০ মিলি'), findsNWidgets(2)); // target figure and row
    expect(find.text('দুপুর ১:৪০'), findsOneWidget);
    expect(find.byTooltip('এন্ট্রি সরান'), findsNWidgets(4));

    await tapOn(tester, find.widgetWithText(DLCard, '২৫০ মিলি'));
    expect(find.text('২৫০ মিলি যোগ হয়েছে'), findsOneWidget);
    expect(await waterToday(db), 1750);

    await tapOn(tester, find.widgetWithText(DLCard, 'নিজস্ব'));
    expect(find.byType(DLSheet), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byType(DLSheet), matching: find.byType(EditableText)), '30');
    await tapOn(tester, find.descendant(of: find.byType(DLSheet), matching: find.text('সংরক্ষণ করুন')));
    expect(find.text('৫০ থেকে ২০০০ মিলির মধ্যে লিখুন'), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byType(DLSheet), matching: find.byType(EditableText)), '৩০০');
    await tapOn(tester, find.descendant(of: find.byType(DLSheet), matching: find.text('সংরক্ষণ করুন')));
    expect(find.byType(DLSheet), findsNothing);
    expect(find.text('৩০০ মিলি যোগ হয়েছে'), findsOneWidget);
    expect(await waterToday(db), 2050);

    await tapOn(tester, find.text('দৈনিক লক্ষ্য').last);
    await tester.enterText(find.descendant(of: find.byType(DLSheet), matching: find.byType(EditableText)), '2000');
    await tapOn(tester, find.descendant(of: find.byType(DLSheet), matching: find.text('সংরক্ষণ করুন')));
    expect(find.text('লক্ষ্য হালনাগাদ হয়েছে'), findsOneWidget);
    expect(containerOf(tester).read(waterTargetProvider), 2000);
    expect(find.text('আজকের লক্ষ্য পূরণ হয়েছে!'), findsOneWidget);

    await tapOn(tester, find.byTooltip('এন্ট্রি সরান').first);
    expect(find.byTooltip('এন্ট্রি সরান'), findsNWidgets(5));

    await tapOn(tester, find.byType(DLSwitch));
    expect(containerOf(tester).read(notificationPrefsProvider)[NotifKind.water], isFalse);
  });

  testWidgets('food: today\'s four meals, history, add, edit and delete (screens 59–60)', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTall);
    await openRoute(tester, Routes.healthTab(HealthTab.food));
    expect(find.text('২টি খাবার / ৪'), findsOneWidget);
    expect(find.text('রুটি, ডিম ভাজি ও চা'), findsOneWidget);
    expect(find.text('এখনো যোগ করা হয়নি'), findsNWidgets(2));
    expect(find.text('গতকাল · ৫ নভেম্বর, বৃহস্পতিবার'), findsOneWidget);
    expect(find.text('খিচুড়ি ও ডিম'), findsOneWidget);

    // Add: the first meal not logged today (the snack).
    await tapOn(tester, find.widgetWithText(DLButton, 'খাবার যোগ করুন'));
    expect(titleBar('খাবার যোগ করুন'), findsOneWidget);
    expect(tester.widget<DLChip>(find.widgetWithText(DLChip, 'বিকালের নাশতা')).selected, isTrue);
    await tapOn(tester, find.text('সংরক্ষণ করুন'));
    expect(find.text('একটি নাম লিখুন'), findsOneWidget);
    await typeInto(tester, 'কী খেলেন', 'মুড়ি ও চা');
    await tapOn(tester, find.text('সংরক্ষণ করুন'));
    expect(find.text('খাবার সংরক্ষণ হয়েছে'), findsOneWidget);
    expect(find.text('৩টি খাবার / ৪'), findsOneWidget);
    final snack = (await db.select(db.meals).get()).singleWhere((m) => m.description == 'মুড়ি ও চা');
    expect((snack.type, snack.time, dayKey(snack.date)), (MealType.snack, '17:00', '2026-11-06'));

    // Edit breakfast, then delete it.
    await tapOn(tester, find.byTooltip('খাবার সম্পাদনা').first);
    expect(titleBar('খাবার সম্পাদনা'), findsOneWidget);
    await tapOn(tester, find.byTooltip('মুছে ফেলুন'));
    expect(find.text('খাবারটি মুছে ফেলবেন?'), findsOneWidget);
    await tapOn(tester, find.descendant(of: find.byType(DLConfirmDialog), matching: find.text('মুছে ফেলুন')));
    expect(find.text('খাবার মুছে ফেলা হয়েছে'), findsOneWidget);
    expect(await db.healthDao.mealById('m1'), isNull);
    expect(find.text('২টি খাবার / ৪'), findsOneWidget);
  });

  testWidgets('habits: today, streaks, week strip, tick, add (screen 61)', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTall);
    await openRoute(tester, Routes.healthTab(HealthTab.habits));
    expect(find.text('আজ ৩/৬ সম্পন্ন'), findsOneWidget);
    expect(find.text('৫০%'), findsOneWidget);
    expect(find.text('৮ দিনের ধারা'), findsOneWidget); // reading: up to yesterday
    expect(find.text('৭ দিনের ধারা'), findsOneWidget); // learning
    expect(find.text('৪ দিনের ধারা'), findsOneWidget); // waking early

    final reading = find.ancestor(of: find.text('বই পড়া'), matching: find.byType(DLCard)).first;
    await tapOn(tester, find.descendant(of: reading, matching: find.byType(DLCheckbox)));
    expect(find.text('আজ ৪/৬ সম্পন্ন'), findsOneWidget);
    expect(find.text('৯ দিনের ধারা'), findsOneWidget);
    expect((await db.select(db.habitChecks).get()).any((c) => c.habitId == 'h1' && dayKey(c.date) == '2026-11-06'), isTrue);

    await tapOn(tester, find.text('অভ্যাস যোগ করুন'));
    await tapOn(tester, find.descendant(of: find.byType(DLSheet), matching: find.text('সংরক্ষণ করুন')));
    expect(find.text('একটি নাম লিখুন'), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byType(DLSheet), matching: find.byType(EditableText)), 'ধ্যান');
    await tapOn(tester, find.descendant(of: find.byType(DLSheet), matching: find.text('সংরক্ষণ করুন')));
    expect(find.text('অভ্যাস যোগ হয়েছে'), findsOneWidget);
    expect(find.text('ধ্যান'), findsOneWidget);
    expect(find.text('আজ ৪/৭ সম্পন্ন'), findsOneWidget);
  });

  testWidgets('habit details: streaks, month calendar, past days toggle, delete (screen 62)', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTall);
    await openRoute(tester, Routes.habit('h1'));
    expect(titleBar('বই পড়া'), findsOneWidget);
    expect(find.text('বর্তমান ধারা'), findsOneWidget);
    expect(find.text('৮'), findsNWidgets(3)); // current and best streak, and the day-8 cell
    expect(find.text('৮৩%'), findsOneWidget);
    expect(find.text('নভেম্বর ২০২৬'), findsOneWidget);
    expect(find.text('৬/৭'), findsOneWidget);
    expect(find.text('রাত ১০:০০'), findsOneWidget);

    // A past day toggles; a future day doesn't.
    await tapOn(tester, find.text('৬').last);
    expect((await db.select(db.habitChecks).get()).any((c) => c.habitId == 'h1' && dayKey(c.date) == '2026-11-06'), isTrue);
    expect(find.text('৯'), findsNWidgets(3)); // streaks 9 and 9, and the day-9 cell
    await tester.tap(find.text('২০'));
    await tester.pumpAndSettle();
    expect((await db.select(db.habitChecks).get()).any((c) => c.habitId == 'h1' && dayKey(c.date) == '2026-11-20'), isFalse);

    await tapOn(tester, find.byTooltip('মুছে ফেলুন'));
    expect(find.text('অভ্যাসটি মুছে ফেলবেন?'), findsOneWidget);
    await tapOn(tester, find.descendant(of: find.byType(DLConfirmDialog), matching: find.text('মুছে ফেলুন')));
    expect(find.text('অভ্যাস মুছে ফেলা হয়েছে'), findsOneWidget);
    expect((await db.select(db.habits).get()).any((h) => h.id == 'h1'), isFalse);
  });

  testWidgets('Home tiles open the matching Health tab; More opens Health', (tester) async {
    await pumpApp(tester, sampleData: true, size: const Size(393, 3000));
    await tapOn(tester, find.ancestor(of: find.text('অভ্যাস'), matching: find.byType(DLCard)).first);
    expect(find.byType(HealthScreen), findsOneWidget);
    expect(tester.widget<HealthScreen>(find.byType(HealthScreen)).tab, HealthTab.habits);
    expect(find.text('আজ ৩/৬ সম্পন্ন'), findsOneWidget);
  });

  testWidgets('no data: empty water log and habits', (tester) async {
    await pumpApp(tester, size: kTall);
    await openRoute(tester, Routes.health);
    expect(find.text('আজ এখনো পানি যোগ করা হয়নি'), findsOneWidget);
    expect(find.text('০%'), findsOneWidget);
    await tapOn(tester, find.text('অভ্যাস'));
    expect(find.text('এখনো কোনো অভ্যাস নেই'), findsOneWidget);
    await tapOn(tester, find.text('খাবার'));
    expect(find.text('এখনো যোগ করা হয়নি'), findsNWidgets(4));
  });
}
