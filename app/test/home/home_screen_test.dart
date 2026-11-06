// Build step 5: the Home dashboard (prototype `home`, screenshots 05–08 and 90)
// on the sample data in Bengali, with the pinned clock (2026-11-06 09:30).
import 'package:dailylife/core/db/app_database.dart';
import 'package:dailylife/core/prefs/app_settings.dart';
import 'package:dailylife/core/prefs/dashboard_layout.dart';
import 'package:dailylife/core/widgets/dl_widgets.dart';
import 'package:dailylife/features/finance/finance_screen.dart';
import 'package:dailylife/features/finance/money_providers.dart';
import 'package:dailylife/features/home/home_screen.dart';
import 'package:dailylife/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

/// Tall enough that the whole dashboard builds without scrolling.
const kWholeHome = Size(393, 3000);

Finder inHero(Finder f) => find.descendant(of: find.byType(DLBalanceHero), matching: f);

/// The "today" tile labelled [label].
Finder tile(String label) => find.ancestor(of: find.text(label), matching: find.byType(DLCard)).first;

/// The unread dot on the bell.
Finder bellDot() => find.descendant(of: find.byType(DLAppBar), matching: find.byType(DLDot));

Finder inSheet(Finder f) => find.descendant(of: find.byType(DLSheet), matching: f);

/// A row of the customize sheet.
Finder sheetRow(String label) => find.ancestor(of: inSheet(find.text(label)), matching: find.byType(Row)).first;

DLIconButton arrow(WidgetTester tester, String label, String tooltip) => tester.widget<DLIconButton>(
      find.descendant(of: sheetRow(label), matching: find.byWidgetPredicate((w) => w is DLIconButton && w.tooltip == tooltip)),
    );

List<String> recentTitles(WidgetTester tester) => [for (final r in tester.widgetList<TxRow>(find.byType(TxRow))) r.x.title];

void main() {
  testWidgets('dashboard shows the month, today and the latest transactions (screen 05)', (tester) async {
    await pumpApp(tester, sampleData: true, size: kWholeHome, prefs: {PrefKeys.displayName: 'Swapnil'});

    // Date bar and greeting.
    expect(find.text('৬ নভেম্বর, শুক্রবার'), findsOneWidget);
    expect(find.text('২১ কার্তিক ১৪৩৩'), findsOneWidget);
    expect(find.text('শুভ সকাল, Swapnil!'), findsOneWidget);
    expect(find.text('S'), findsOneWidget);
    expect(bellDot(), findsOneWidget);

    // Summary.
    expect(inHero(find.text('নভেম্বর ২০২৬')), findsOneWidget);
    expect(inHero(find.text('৳১৭,১২০')), findsOneWidget);
    expect(inHero(find.text('৳৫০,০০০')), findsOneWidget);
    expect(inHero(find.text('৳২২,৮৮০')), findsOneWidget);
    expect(find.text('৳১,২৫,০০০'), findsOneWidget);
    expect(find.text('+৳১০,০০০ এ মাসে'), findsOneWidget);

    // Chart: 6 months, the current one selected.
    final chart = tester.widget<DLBarChart>(find.byType(DLBarChart));
    expect(chart.groups.length, 6);
    expect(chart.selectedIndex, 5);
    expect([for (final g in chart.groups) g.label], ['জুন', 'জুলা', 'আগ', 'সেপ্টে', 'অক্টো', 'নভে']);
    expect(find.text('নিট ৳২৭,১২০'), findsOneWidget);
    expect(find.text('+৳৫০,০০০'), findsOneWidget);
    expect(find.text('−৳২২,৮৮০'), findsOneWidget);

    // Today's overview.
    for (final (label, value, sub) in [
      ('সম্পন্ন কাজ', '১/৪', '৪টি কাজ'),
      ('বাকি কাজ', '৩', 'রোল-ভিত্তিক পারমিশন টেস্ট'),
      ('মিটিং', '১', 'সকাল ১০:০০ · টিম স্ট্যান্ডআপ'),
      ('ইভেন্ট', '১', 'পরিবারের সাথে রাতের খাবার'),
      ('রিমাইন্ডার', '৩', 'বিকাল ৫:০০ · সাপ্তাহিক রিপোর্ট জমা দিন'),
      ('পানি', '৫০%', '১,৫০০ মিলি / ৩,০০০ মিলি'),
      ('খাবার', '২/৪', 'সকালের নাশতা, দুপুরের খাবার'),
      ('অভ্যাস', '৩/৬', 'আজ ৩/৬ সম্পন্ন'),
    ]) {
      expect(find.descendant(of: tile(label), matching: find.text(value)), findsOneWidget, reason: label);
      expect(find.descendant(of: tile(label), matching: find.text(sub)), findsOneWidget, reason: label);
    }

    // Shop credit, quick actions, recent transactions.
    expect(find.text('৳১,৮৫০'), findsOneWidget);
    expect(find.text('২টি দোকানে বাকি'), findsOneWidget);
    for (final label in ['আয় যোগ করুন', 'খরচ যোগ করুন', 'কাজ যোগ করুন', 'নোট লিখুন', 'রিমাইন্ডার দিন']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(recentTitles(tester), ['দুপুরের খাবার', 'মায়ের দোয়া স্টোরে পরিশোধ', 'সপ্তাহান্তের অতিরিক্ত কাজ', 'বাড়িতে টাকা পাঠানো', 'ইন্টারনেট বিল']);
    expect(find.text('খাবার · আজ'), findsOneWidget);
    expect(find.text('পরিবার · গতকাল'), findsOneWidget);
    expect(find.text('ড্যাশবোর্ড সাজান'), findsOneWidget);
  });

  testWidgets('the month sheet changes the month on Home and Finance alike (screen 06)', (tester) async {
    await pumpApp(tester, sampleData: true, size: kWholeHome);
    await tapOn(tester, inHero(find.text('নভেম্বর ২০২৬')));
    expect(find.text('মাস বেছে নিন'), findsOneWidget);
    expect(find.descendant(of: find.byType(DLSheet), matching: find.byType(DLListRow)), findsNWidgets(6));

    await tapOn(tester, find.text('অক্টোবর ২০২৬'));
    expect(find.byType(DLSheet), findsNothing);
    expect(inHero(find.text('অক্টোবর ২০২৬')), findsOneWidget);
    expect(inHero(find.text('−৳৭০০')), findsOneWidget);
    expect(inHero(find.text('৳৪৭,৫০০')), findsOneWidget);
    expect(inHero(find.text('৳৩৪,২০০')), findsOneWidget);
    expect(find.text('+৳১৪,০০০ এ মাসে'), findsOneWidget);

    await tester.tap(navLabel('হিসাব'));
    await tester.pumpAndSettle();
    expect(containerOf(tester).read(selectedMonthProvider), DateTime(2026, 10));
    expect(find.text('অক্টোবর ২০২৬'), findsOneWidget);
    expect(inHero(find.text('−৳৭০০')), findsOneWidget);
  });

  testWidgets('chart: a tapped bar shows that month; 12 months keeps the choice', (tester) async {
    await pumpApp(tester, sampleData: true, size: kWholeHome);
    final rect = tester.getRect(find.byType(DLBarChart));
    final groupWidth = (rect.width - 6 * 5) / 6;
    await tester.tapAt(Offset(rect.left + 4 * (groupWidth + 6) + groupWidth / 2, rect.top + 75)); // October
    await tester.pumpAndSettle();
    expect(tester.widget<DLBarChart>(find.byType(DLBarChart)).selectedIndex, 4);
    expect(find.text('নিট ৳১৩,৩০০'), findsOneWidget);
    expect(find.text('+৳৪৭,৫০০'), findsOneWidget);
    expect(find.text('−৳৩৪,২০০'), findsOneWidget);
    // The hero keeps its own month.
    expect(inHero(find.text('নভেম্বর ২০২৬')), findsOneWidget);

    await tapOn(tester, find.text('১২ মাস'));
    final chart = tester.widget<DLBarChart>(find.byType(DLBarChart));
    expect(chart.groups.length, 12);
    expect(chart.selectedIndex, 10);
    expect([for (final g in chart.groups) g.label].where((l) => l.isEmpty).length, 6); // every other label
    expect(find.text('নিট ৳১৩,৩০০'), findsOneWidget);
  });

  testWidgets('customize: hide and reorder sections, saved at once (screen 07)', (tester) async {
    await pumpApp(tester, sampleData: true, size: kWholeHome);
    await tapOn(tester, find.text('ড্যাশবোর্ড সাজান'));
    expect(find.byType(DLSheet), findsOneWidget);
    expect(inSheet(find.text('সেকশন দেখান বা লুকান, তীর দিয়ে ক্রম বদলান।')), findsOneWidget);
    expect(arrow(tester, 'আর্থিক সারাংশ', 'উপরে নিন').onPressed, isNull);
    expect(arrow(tester, 'সাম্প্রতিক লেনদেন', 'নিচে নিন').onPressed, isNull);

    await tapOn(tester, find.descendant(of: sheetRow('আয় বনাম খরচ চার্ট'), matching: find.byType(DLSwitch)));
    await tapOn(tester, find.descendant(of: sheetRow('সাম্প্রতিক লেনদেন'), matching: find.byTooltip('উপরে নিন')));
    expect(arrow(tester, 'দ্রুত কাজ', 'নিচে নিন').onPressed, isNull); // now last

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(PrefKeys.dashOrder), ['summary', 'chart', 'today', 'shop', 'recent', 'quick']);
    expect(prefs.getStringList(PrefKeys.dashHidden), ['chart']);

    await tapOn(tester, inSheet(find.text('সম্পন্ন')));
    expect(find.byType(DLSheet), findsNothing);
    expect(find.text('ড্যাশবোর্ড হালনাগাদ হয়েছে'), findsOneWidget);
    expect(find.byType(DLBarChart), findsNothing);
    expect(tester.getTopLeft(find.text('সাম্প্রতিক লেনদেন')).dy, lessThan(tester.getTopLeft(find.text('দ্রুত কাজ')).dy));
  });

  testWidgets('a saved layout is restored at startup', (tester) async {
    await pumpApp(tester, sampleData: true, size: kWholeHome, prefs: {
      PrefKeys.dashOrder: ['recent', 'summary', 'chart', 'today', 'shop', 'quick'],
      PrefKeys.dashHidden: ['today', 'shop'],
    });
    expect(containerOf(tester).read(dashboardLayoutProvider).visible, [DashSection.recent, DashSection.summary, DashSection.chart, DashSection.quick]);
    expect(find.text('আজকের কার্যক্রম'), findsNothing);
    expect(find.text('দোকানে মোট বাকি'), findsNothing);
    expect(tester.getTopLeft(find.text('সাম্প্রতিক লেনদেন')).dy, lessThan(tester.getTopLeft(find.byType(DLBalanceHero)).dy));
  });

  testWidgets('notifications: unread dots, mark all read, the bell dot clears (screen 08)', (tester) async {
    await pumpApp(tester, sampleData: true, size: kTallPhone);
    await tapOn(tester, find.byTooltip('নোটিফিকেশন'));
    expect(titleBar('নোটিফিকেশন'), findsOneWidget);
    expect(find.byType(DLListRow), findsNWidgets(4));
    expect(find.descendant(of: find.byType(DLList), matching: find.byType(DLDot)), findsNWidgets(3));
    expect(find.text('মায়ের ওষুধ কিনুন'), findsOneWidget);

    await tapOn(tester, find.text('সব পড়া হয়েছে'));
    expect(find.text('সব নোটিফিকেশন পড়া হয়েছে'), findsOneWidget);
    expect(find.descendant(of: find.byType(DLList), matching: find.byType(DLDot)), findsNothing);

    await tapOn(tester, find.byTooltip('পেছনে যান'));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(bellDot(), findsNothing);
  });

  testWidgets('tapping a notification marks it read and opens where it points', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTallPhone);
    bool isRead(List<InboxItem> items, String id) => items.firstWhere((i) => i.id == id).isRead;

    await openRoute(tester, Routes.notifications);
    await tapOn(tester, find.text('টিম স্ট্যান্ডআপ ১০ মিনিট পর'));
    expect(titleBar('ক্যালেন্ডার'), findsOneWidget);
    expect(isRead(await db.select(db.inboxItems).get(), 'nt2'), isTrue);
    expect(isRead(await db.select(db.inboxItems).get(), 'nt1'), isFalse);

    await openRoute(tester, Routes.notifications);
    await tapOn(tester, find.text('মায়ের দোয়া স্টোরে বাকি ৳১,০০০'));
    expect(titleBar('দোকানের বাকি'), findsOneWidget);
  });

  testWidgets('empty dashboard: zero totals, no-transactions card, empty inbox (screen 90)', (tester) async {
    await pumpApp(tester, size: kWholeHome);
    expect(find.text('শুভ সকাল!'), findsOneWidget);
    expect(inHero(find.text('৳০')), findsNWidgets(3));
    expect(find.text('+৳০ এ মাসে'), findsOneWidget);
    expect(find.descendant(of: tile('সম্পন্ন কাজ'), matching: find.text('০/০')), findsOneWidget);
    expect(find.descendant(of: tile('পানি'), matching: find.text('০%')), findsOneWidget);
    expect(find.descendant(of: tile('খাবার'), matching: find.text('এখনো যোগ করা হয়নি')), findsOneWidget);
    expect(find.text('নেই'), findsNWidgets(4));
    expect(find.text('০টি দোকানে বাকি'), findsOneWidget);
    expect(find.text('এখনো কোনো লেনদেন যোগ করা হয়নি।'), findsOneWidget);
    expect(bellDot(), findsNothing);

    await tapOn(tester, find.widgetWithText(DLButton, 'আয় যোগ করুন'));
    expect(titleBar('আয় যোগ করুন'), findsOneWidget);

    await openRoute(tester, Routes.notifications);
    expect(find.text('নতুন কোনো নোটিফিকেশন নেই'), findsOneWidget);
  });

  testWidgets('bar buttons: theme toggle, settings; quick actions and tiles open their screens', (tester) async {
    await pumpApp(tester, sampleData: true, size: kWholeHome);
    await tapOn(tester, find.byTooltip('থিম বদলান'));
    expect(containerOf(tester).read(settingsProvider).themeMode, ThemeMode.dark);
    expect(Theme.of(tester.element(find.byType(HomeScreen))).brightness, Brightness.dark);
    await tapOn(tester, find.byTooltip('থিম বদলান'));
    expect(containerOf(tester).read(settingsProvider).themeMode, ThemeMode.light);

    await tapOn(tester, find.text('খরচ যোগ করুন'));
    expect(titleBar('খরচ যোগ করুন'), findsOneWidget);
    containerOf(tester).read(routerProvider).pop();
    await tester.pumpAndSettle();

    await tapOn(tester, tile('সম্পন্ন কাজ'));
    expect(titleBar('অফিস ও কাজ'), findsOneWidget);
    await tester.tap(navLabel('হোম'));
    await tester.pumpAndSettle();

    await tapOn(tester, find.text('বাকির খাতা খুলুন'));
    expect(titleBar('দোকানের বাকি'), findsOneWidget);
    await tapOn(tester, find.byTooltip('পেছনে যান'));

    await tapOn(tester, inHero(find.text('মোট খরচ')));
    expect(titleBar('হিসাব'), findsOneWidget);
    expect(containerOf(tester).read(finFilterProvider).tab, FinTab.expense);
  });
}
