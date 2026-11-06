// Build step 6.3: the More tab and Reminders (prototype `more`, `reminders`,
// `addRem`, `remDetail`; screenshots 50–54 and 94) and acceptance journey 8,
// on the sample data in Bengali with the pinned clock (Friday 2026-11-06).
import 'package:dailylife/core/db/app_database.dart';
import 'package:dailylife/core/widgets/dl_widgets.dart';
import 'package:dailylife/features/more/more_screen.dart';
import 'package:dailylife/features/reminders/reminders_providers.dart';
import 'package:dailylife/features/reminders/reminders_ui.dart';
import 'package:dailylife/features/reminders/reminders_screen.dart';
import 'package:dailylife/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

Future<void> openMore(WidgetTester tester) async {
  await tester.tap(navLabel('আরও'));
  await tester.pumpAndSettle();
  expect(find.byType(MoreScreen), findsOneWidget);
}

List<String> cardTitles(WidgetTester tester) => [for (final c in tester.widgetList<ReminderCard>(find.byType(ReminderCard))) c.reminder.title];

/// The reminder card titled [title].
Finder card(String title) => find.ancestor(of: find.text(title), matching: find.byType(ReminderCard));

void main() {
  testWidgets('More: profile, groups with counts and the due badge (screen 50)', (tester) async {
    await pumpApp(tester, sampleData: true, size: kTallPhone);
    await openMore(tester);
    expect(titleBar('আরও'), findsOneWidget);
    for (final s in ['স্থানীয় ডেটা · এই ফোনে', 'আজ ৩টি বাকি', '৫টি নোট', 'পানি, খাবার, অভ্যাস', '৪টি চলমান', '৬টি ফাইল', 'Daily Life · সংস্করণ ০.১.০']) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
    expect(find.descendant(of: find.byType(DLBadge), matching: find.text('৩')), findsOneWidget);

    await tapOn(tester, find.text('রিমাইন্ডার'));
    expect(find.byType(RemindersScreen), findsOneWidget);
    await tapOn(tester, find.byTooltip('পেছনে যান'));
    await tapOn(tester, find.text('নোটবুক'));
    expect(titleBar('নোটবুক'), findsOneWidget);
  });

  testWidgets('Reminders: tabs with counts; Today sorted by time (screens 51–52)', (tester) async {
    await pumpApp(tester, sampleData: true, size: kTallPhone);
    await openRoute(tester, Routes.reminders);
    expect(find.text('আজ (৩)'), findsOneWidget);
    expect(find.text('আসন্ন (২)'), findsOneWidget);
    expect(find.text('সম্পন্ন (২)'), findsOneWidget);
    expect(cardTitles(tester), ['সাপ্তাহিক রিপোর্ট জমা দিন', 'মায়ের ওষুধ কিনুন', '২০ পৃষ্ঠা বই পড়ুন']);
    expect(find.descendant(of: card('মায়ের ওষুধ কিনুন'), matching: find.text('সন্ধ্যা ৬:০০')), findsOneWidget);
    expect(find.descendant(of: card('মায়ের ওষুধ কিনুন'), matching: find.text('উচ্চ')), findsOneWidget);
    expect(find.descendant(of: card('২০ পৃষ্ঠা বই পড়ুন'), matching: find.text('প্রতিদিন')), findsOneWidget);

    await tapOn(tester, find.text('আসন্ন (২)'));
    expect(cardTitles(tester), ['ক্লায়েন্ট ডেমোর স্লাইড', 'বিদ্যুৎ বিল পরিশোধ করুন']);
    expect(find.text('আগামীকাল · রাত ৯:০০'), findsOneWidget);
    expect(find.text('১০ নভে · সকাল ১০:০০'), findsOneWidget);
    // Upcoming reminders can't be snoozed.
    expect(find.text('১০ মিনিট পিছান'), findsNothing);

    await tapOn(tester, find.text('সম্পন্ন (২)'));
    expect(cardTitles(tester), ['ইন্টারনেট বিল দিন', 'সকালে হাঁটা']);
    expect(find.text('আবার চালু করুন'), findsNWidgets(2));
  });

  testWidgets('done, snooze, on/off and overdue', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTallPhone);
    await db.remindersDao.addReminder(RemindersCompanion.insert(
      title: 'পুরনো কাজ',
      date: DateTime(2026, 11, 4),
      time: '09:00',
      priority: PriorityLevel.low,
      category: ReminderCategory.other,
      repeat: RepeatRule.once,
    ));
    await openRoute(tester, Routes.reminders);
    expect(cardTitles(tester).first, 'পুরনো কাজ');
    expect(find.descendant(of: card('পুরনো কাজ'), matching: find.text('সময় পেরিয়ে গেছে')), findsOneWidget);
    expect(find.descendant(of: card('পুরনো কাজ'), matching: find.text('৪ নভে · সকাল ৯:০০')), findsOneWidget);

    await tapOn(tester, find.descendant(of: card('মায়ের ওষুধ কিনুন'), matching: find.text('১০ মিনিট পিছান')));
    expect(find.text('১০ মিনিট পিছানো হয়েছে'), findsOneWidget);
    expect((await db.remindersDao.reminderById('r1'))!.time, '18:10');

    await tapOn(tester, find.descendant(of: card('সাপ্তাহিক রিপোর্ট জমা দিন'), matching: find.byType(DLSwitch)));
    expect((await db.remindersDao.reminderById('r2'))!.enabled, isFalse);

    await tapOn(tester, find.descendant(of: card('সাপ্তাহিক রিপোর্ট জমা দিন'), matching: find.text('সম্পন্ন করুন')));
    expect(find.text('রিমাইন্ডার সম্পন্ন হয়েছে'), findsOneWidget);
    expect((await db.remindersDao.reminderById('r2'))!.done, isTrue);
    expect(find.text('আজ (৩)'), findsOneWidget);
    expect(find.text('সম্পন্ন (৩)'), findsOneWidget);
  });

  testWidgets('journey 8: More → Reminders → add with custom days → listed under the right tab', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTallPhone);
    await openMore(tester);
    await tapOn(tester, find.text('রিমাইন্ডার'));
    await tapOn(tester, find.byTooltip('রিমাইন্ডার দিন').first);
    expect(titleBar('নতুন রিমাইন্ডার'), findsOneWidget);

    await tapOn(tester, find.text('সংরক্ষণ করুন'));
    expect(find.text('একটি নাম লিখুন'), findsOneWidget);
    await typeInto(tester, 'শিরোনাম', 'জিমে যাওয়া');
    await tapOn(tester, find.widgetWithText(DLChip, 'স্বাস্থ্য'));
    await tapOn(tester, find.widgetWithText(DLChip, 'নিজস্ব'));
    expect(find.text('কোন কোন দিন'), findsOneWidget);
    await tapOn(tester, find.text('শনি'));
    await tapOn(tester, find.text('বুধ'));
    await tapOn(tester, find.text('সংরক্ষণ করুন'));

    expect(find.text('রিমাইন্ডার সংরক্ষণ হয়েছে'), findsOneWidget);
    expect(find.byType(RemindersScreen), findsOneWidget);
    expect(containerOf(tester).read(remTabProvider), RemTab.today);
    expect(find.text('আজ (৪)'), findsOneWidget);
    expect(cardTitles(tester), contains('জিমে যাওয়া'));
    expect(find.descendant(of: card('জিমে যাওয়া'), matching: find.text('নিজস্ব')), findsOneWidget);

    final saved = (await db.select(db.reminders).get()).singleWhere((r) => r.title == 'জিমে যাওয়া');
    expect((saved.repeat, saved.category, saved.time, saved.enabled), (RepeatRule.custom, ReminderCategory.health, '18:00', true));
    expect(saved.customDays, {0, 4});
  });

  testWidgets('a reminder for a later day lands on Upcoming; from Home the list opens', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: const Size(393, 3000));
    await tapOn(tester, find.text('রিমাইন্ডার দিন'));
    expect(titleBar('নতুন রিমাইন্ডার'), findsOneWidget);
    await typeInto(tester, 'শিরোনাম', 'বাড়ি ভাড়া দিন');
    await tapOn(tester, find.text('সংরক্ষণ করুন'));
    expect(find.byType(RemindersScreen), findsOneWidget);

    // Moved to tomorrow, the reminder belongs to Upcoming.
    final r = (await db.select(db.reminders).get()).singleWhere((r) => r.title == 'বাড়ি ভাড়া দিন');
    await db.remindersDao.updateReminder(r.copyWith(date: DateTime(2026, 11, 7)));
    await openRoute(tester, Routes.editReminder(r.id));
    await tapOn(tester, find.text('সংরক্ষণ করুন'));
    expect(containerOf(tester).read(remTabProvider), RemTab.upcoming);
    expect(cardTitles(tester), contains('বাড়ি ভাড়া দিন'));
  });

  testWidgets('reminder details: preview, facts, switch, edit and delete (screen 54)', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTallPhone);
    await openRoute(tester, Routes.reminders);
    await tapOn(tester, find.text('মায়ের ওষুধ কিনুন'));
    expect(titleBar('রিমাইন্ডারের বিবরণ'), findsOneWidget);
    expect(find.text('Daily Life · সন্ধ্যা ৬:০০'), findsOneWidget);
    expect(find.text('রহিম ফার্মেসি থেকে'), findsOneWidget);
    for (final v in ['৬ নভেম্বর, শুক্রবার', 'সন্ধ্যা ৬:০০', 'একবার', 'ব্যক্তিগত', 'বাকি']) {
      expect(find.widgetWithText(DLKeyValueRow, v), findsOneWidget, reason: v);
    }
    expect(find.byType(DLLogo), findsOneWidget);

    await tapOn(tester, find.byType(DLSwitch));
    expect((await db.remindersDao.reminderById('r1'))!.enabled, isFalse);

    await tapOn(tester, find.byTooltip('সম্পাদনা করুন'));
    expect(titleBar('রিমাইন্ডার সম্পাদনা'), findsOneWidget);
    await typeInto(tester, 'শিরোনাম', 'মায়ের ওষুধ আনুন');
    await tapOn(tester, find.text('সংরক্ষণ করুন'));
    expect(titleBar('রিমাইন্ডারের বিবরণ'), findsOneWidget);
    expect(find.text('মায়ের ওষুধ আনুন'), findsOneWidget);
    expect((await db.remindersDao.reminderById('r1'))!.enabled, isFalse);

    await tapOn(tester, find.byTooltip('মুছে ফেলুন'));
    expect(find.text('রিমাইন্ডারটি মুছে ফেলবেন?'), findsOneWidget);
    await tapOn(tester, find.descendant(of: find.byType(DLConfirmDialog), matching: find.text('মুছে ফেলুন')));
    expect(await db.remindersDao.reminderById('r1'), isNull);
    expect(find.byType(RemindersScreen), findsOneWidget);
    expect(find.text('আজ (২)'), findsOneWidget);
  });

  testWidgets('no reminders: empty state with an add button (screen 94)', (tester) async {
    await pumpApp(tester, size: kTallPhone);
    await openRoute(tester, Routes.reminders);
    expect(find.text('এখানে কোনো রিমাইন্ডার নেই'), findsOneWidget);
    expect(find.text('আজ (০)'), findsOneWidget);
    await tapOn(tester, find.widgetWithText(DLButton, 'রিমাইন্ডার দিন'));
    expect(titleBar('নতুন রিমাইন্ডার'), findsOneWidget);
  });

  testWidgets('a new reminder can start switched off', (tester) async {
    final db = await pumpApp(tester, size: kTallPhone);
    await openRoute(tester, Routes.newReminder());
    await typeInto(tester, 'শিরোনাম', 'চুপচাপ');
    await tapOn(tester, find.byType(DLSwitch));
    await tapOn(tester, find.text('সংরক্ষণ করুন'));
    final r = (await db.select(db.reminders).get()).single;
    expect((r.title, r.enabled), ('চুপচাপ', false));
    expect(r.customDays, isEmpty);
  });
}
