// Build step 6.2: the Calendar tab's month, week, day and agenda views, the
// event form and details (prototype `calendar` … `eventDetail`, screenshots
// 40–45), and acceptance journey 7, on the sample data in Bengali with the
// pinned clock (Friday 2026-11-06).
import 'package:dailylife/core/db/app_database.dart';
import 'package:dailylife/core/theme/dl_tokens.dart';
import 'package:dailylife/core/widgets/dl_widgets.dart';
import 'package:dailylife/features/calendar/calendar_providers.dart';
import 'package:dailylife/features/calendar/calendar_screen.dart';
import 'package:dailylife/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

Future<void> openCalendar(WidgetTester tester) async {
  await tester.tap(navLabel('ক্যালেন্ডার'));
  await tester.pumpAndSettle();
  expect(find.byType(CalendarScreen), findsOneWidget);
}

/// The month grid's cell showing day [n] (Bengali digits), within the month.
Finder dayCell(String n) => find.ancestor(of: find.text(n), matching: find.byType(DLPressable)).first;

/// The category dots under day [n].
Finder dotsOf(String n) => find.descendant(of: dayCell(n), matching: find.byType(DLDot));

void main() {
  testWidgets('month view: Saturday-first grid, Bangla months, dots and today\'s events (screen 40)', (tester) async {
    await pumpApp(tester, sampleData: true, size: kTallPhone);
    await openCalendar(tester);
    expect(titleBar('ক্যালেন্ডার'), findsOneWidget);
    expect(find.text('নভেম্বর ২০২৬'), findsOneWidget);
    expect(find.text('কার্তিক–অগ্রহায়ণ ১৪৩৩'), findsOneWidget);
    // 5 weeks: 31 Oct … 4 Dec.
    expect(find.text('৩১'), findsOneWidget);
    expect(find.text('৪'), findsWidgets);

    // Up to 3 category dots a day: payday, today's two, the weekly standup.
    expect(dotsOf('১'), findsWidgets);
    expect(dotsOf('৬'), findsNWidgets(2));
    expect(dotsOf('১৩'), findsOneWidget);
    expect(dotsOf('১৫'), findsNothing);

    // Today's events under the grid.
    expect(find.text('আজ · ৬ নভেম্বর, শুক্রবার'), findsOneWidget);
    expect(find.text('২১ কার্তিক ১৪৩৩'), findsOneWidget);
    expect(find.text('টিম স্ট্যান্ডআপ'), findsOneWidget);
    expect(find.text('পরিবারের সাথে রাতের খাবার'), findsOneWidget);
    expect(find.text('গুগল মিট'), findsOneWidget);

    // Another day; then the month pager and Today.
    await tapOn(tester, dayCell('৮'));
    expect(find.text('৮ নভেম্বর, রবিবার'), findsOneWidget);
    expect(find.text('ক্লায়েন্ট ডেমো — Baselinq'), findsOneWidget);
    await tapOn(tester, find.byTooltip('পরের মাস'));
    expect(find.text('ডিসেম্বর ২০২৬'), findsOneWidget);
    expect(find.text('৮ নভেম্বর, রবিবার'), findsOneWidget);
    await tapOn(tester, find.widgetWithText(DLButton, 'আজ'));
    expect(find.text('নভেম্বর ২০২৬'), findsOneWidget);
    expect(find.text('আজ · ৬ নভেম্বর, শুক্রবার'), findsOneWidget);
  });

  testWidgets('week, day and agenda views (screens 41–43)', (tester) async {
    await pumpApp(tester, sampleData: true, size: const Size(393, 2400));
    await openCalendar(tester);

    await tapOn(tester, find.text('সপ্তাহ'));
    expect(find.text('৩১ অক্টো – ৬ নভে ২০২৬'), findsOneWidget);
    await tapOn(tester, find.byTooltip('পরের মাস'));
    expect(find.text('৭ নভে – ১৩ নভে ২০২৬'), findsOneWidget);
    expect(containerOf(tester).read(calendarProvider).selected, DateTime(2026, 11, 13));
    expect(find.text('টিম স্ট্যান্ডআপ'), findsOneWidget);

    await tapOn(tester, find.text('দিন'));
    expect(find.text('১৩ নভেম্বর, শুক্রবার'), findsOneWidget);
    await tapOn(tester, find.byTooltip('গতকাল'));
    expect(find.text('১২ নভেম্বর, বৃহস্পতিবার'), findsOneWidget);
    expect(find.text('স্প্রিন্ট রেট্রো'), findsOneWidget);
    expect(find.text('বিকাল ৪:০০ – বিকাল ৫:০০'), findsOneWidget);
    // Hour rows from 7 AM to 11 PM.
    expect(find.text('সকাল ৭:০০'), findsOneWidget);
    expect(find.text('রাত ১১:০০'), findsOneWidget);

    await tapOn(tester, find.text('এজেন্ডা'));
    expect(find.text('আজ · ৬ নভেম্বর, শুক্রবার'), findsOneWidget);
    expect(find.text('৮ নভেম্বর, রবিবার'), findsOneWidget);
    expect(find.text('১ ডিসেম্বর, মঙ্গলবার'), findsOneWidget);
    expect(find.text('বেতন দিবস'), findsOneWidget);
    expect(find.text('সারাদিন'), findsWidgets);

    // An event opens its details.
    await tapOn(tester, find.text('বেতন দিবস'));
    expect(titleBar('ইভেন্টের বিবরণ'), findsOneWidget);
  });

  testWidgets('journey 7: select a date → add event → event details; a dot on that date', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTallPhone);
    await openCalendar(tester);
    await tapOn(tester, dayCell('১৮'));
    expect(find.text('১৮ নভেম্বর, বুধবার'), findsOneWidget);
    expect(find.text('এই দিনে কোনো ইভেন্ট নেই'), findsOneWidget);
    expect(dotsOf('১৮'), findsNothing);

    await tapOn(tester, find.widgetWithText(DLLinkButton, 'যোগ করুন'));
    expect(titleBar('ইভেন্ট যোগ করুন'), findsOneWidget);
    // The new event starts on the selected day, 10–11 AM.
    expect(find.text('১৮ নভেম্বর, বুধবার · সকাল ১০:০০ – সকাল ১১:০০'), findsOneWidget);

    await tapOn(tester, find.text('সংরক্ষণ করুন'));
    expect(find.text('একটি নাম লিখুন'), findsOneWidget);
    await typeInto(tester, 'শিরোনাম', 'ডাক্তারের অ্যাপয়েন্টমেন্ট');
    await typeInto(tester, 'স্থান', 'ল্যাবএইড');
    await tapOn(tester, find.widgetWithText(DLChip, 'ব্যক্তিগত'));
    await tapOn(tester, find.widgetWithText(DLChip, '১ ঘণ্টা আগে'));
    await tapOn(tester, find.text('সংরক্ষণ করুন'));

    expect(find.text('ইভেন্ট সংরক্ষণ হয়েছে'), findsOneWidget);
    expect(titleBar('ইভেন্টের বিবরণ'), findsOneWidget);
    expect(find.text('ডাক্তারের অ্যাপয়েন্টমেন্ট'), findsOneWidget);
    expect(find.text('১৮ নভেম্বর, বুধবার, ২০২৬'), findsOneWidget);
    expect(find.text('রিমাইন্ডার: ১ ঘণ্টা আগে'), findsOneWidget);
    expect(find.text('পুনরাবৃত্তি: একবার'), findsOneWidget);
    expect(find.text('ল্যাবএইড'), findsOneWidget);

    final saved = (await db.calendarDao.allEvents()).singleWhere((e) => e.title == 'ডাক্তারের অ্যাপয়েন্টমেন্ট');
    expect((saved.category, saved.startDate, saved.startTime, saved.endTime, saved.reminderMinutes),
        (EventCategory.personal, DateTime(2026, 11, 18), '10:00', '11:00', 60));

    // Back on the calendar (the form was replaced): a teal dot on the 18th.
    await tapOn(tester, find.byTooltip('পেছনে যান'));
    expect(find.byType(CalendarScreen), findsOneWidget);
    expect(dotsOf('১৮'), findsOneWidget);
    final dot = tester.widget<DLDot>(dotsOf('১৮'));
    expect(dot.color, tester.element(find.byType(CalendarScreen)).dl.catTask);
    expect(find.text('ডাক্তারের অ্যাপয়েন্টমেন্ট'), findsOneWidget);
  });

  testWidgets('event details: facts, edit and delete (screen 45)', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTallPhone);
    await openRoute(tester, Routes.event('ev1'));
    expect(titleBar('ইভেন্টের বিবরণ'), findsOneWidget);
    for (final s in [
      'মিটিং',
      'টিম স্ট্যান্ডআপ',
      '৬ নভেম্বর, শুক্রবার, ২০২৬',
      'সকাল ১০:০০ – সকাল ১০:৩০',
      '২১ কার্তিক ১৪৩৩',
      'গুগল মিট',
      'রিমাইন্ডার: ১০ মিনিট আগে',
      'পুনরাবৃত্তি: প্রতি সপ্তাহে',
    ]) {
      expect(find.text(s), findsOneWidget, reason: s);
    }

    await tapOn(tester, find.byTooltip('সম্পাদনা করুন'));
    expect(titleBar('ইভেন্ট সম্পাদনা'), findsOneWidget);
    expect(tester.widget<DLChip>(find.widgetWithText(DLChip, 'প্রতি সপ্তাহে')).selected, isTrue);
    // All day hides the times.
    await tapOn(tester, find.byType(DLSwitch));
    expect(find.text('শুরুর সময়'), findsNothing);
    await typeInto(tester, 'শিরোনাম', 'সাপ্তাহিক স্ট্যান্ডআপ');
    await tapOn(tester, find.text('সংরক্ষণ করুন'));
    expect(titleBar('ইভেন্টের বিবরণ'), findsOneWidget);
    expect(find.text('সাপ্তাহিক স্ট্যান্ডআপ'), findsOneWidget);
    expect(find.text('সারাদিন'), findsOneWidget);
    final edited = (await db.calendarDao.eventById('ev1'))!;
    expect((edited.startTime, edited.endTime, edited.repeat), (null, null, RepeatRule.weekly));

    await tapOn(tester, find.byTooltip('মুছে ফেলুন'));
    expect(find.text('ইভেন্টটি মুছে ফেলবেন?'), findsOneWidget);
    await tapOn(tester, find.descendant(of: find.byType(DLConfirmDialog), matching: find.text('মুছে ফেলুন')));
    expect(find.text('ইভেন্ট মুছে ফেলা হয়েছে'), findsOneWidget);
    expect(await db.calendarDao.eventById('ev1'), isNull);
  });

  testWidgets('no events: empty day list and agenda', (tester) async {
    await pumpApp(tester, size: kTallPhone);
    await openCalendar(tester);
    expect(find.text('এই দিনে কোনো ইভেন্ট নেই'), findsOneWidget);
    expect(find.byType(DLDot), findsNWidgets(6)); // the legend only
    await tapOn(tester, find.text('এজেন্ডা'));
    expect(find.text('এই দিনে কোনো ইভেন্ট নেই'), findsOneWidget);
    await tapOn(tester, find.widgetWithText(DLButton, 'ইভেন্ট যোগ করুন'));
    expect(titleBar('ইভেন্ট যোগ করুন'), findsOneWidget);
  });

  testWidgets('Home: the meeting tile opens today's day view, Agenda the agenda', (tester) async {
    await pumpApp(tester, sampleData: true, size: const Size(393, 3000));
    containerOf(tester).read(calendarProvider.notifier).select(DateTime(2026, 11, 20));

    await tapOn(tester, find.ancestor(of: find.text('মিটিং'), matching: find.byType(DLCard)).first);
    expect(find.byType(CalendarScreen), findsOneWidget);
    var cal = containerOf(tester).read(calendarProvider);
    expect((cal.view, cal.selected), (CalView.day, DateTime(2026, 11, 6)));
    expect(find.text('আজ · ৬ নভেম্বর, শুক্রবার'), findsOneWidget);

    await tester.tap(navLabel('হোম'));
    await tester.pumpAndSettle();
    await tapOn(tester, find.widgetWithText(DLLinkButton, 'এজেন্ডা'));
    cal = containerOf(tester).read(calendarProvider);
    expect(cal.view, CalView.agenda);
  });
}
