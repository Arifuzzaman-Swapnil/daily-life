// Build step 4 screens beyond the journeys: validation, search and filters,
// delete with confirmation, categories, savings, empty states, and every
// screen and sheet on a small phone in both languages and themes.
import 'package:dailylife/core/db/app_database.dart';
import 'package:dailylife/core/prefs/app_settings.dart';
import 'package:dailylife/core/widgets/dl_widgets.dart';
import 'package:dailylife/features/finance/finance_screen.dart';
import 'package:dailylife/features/finance/money_providers.dart';
import 'package:dailylife/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

Future<void> openFinance(WidgetTester tester) async {
  await tester.tap(navLabel('হিসাব'));
  await tester.pumpAndSettle();
}

List<String> listedTitles(WidgetTester tester) => [for (final r in tester.widgetList<TxRow>(find.byType(TxRow))) r.x.title];

void main() {
  testWidgets('saving an empty expense shows every error and saves nothing (screen 16)', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTallPhone);
    final before = (await db.financeDao.transactionsIn()).length;
    await openRoute(tester, Routes.newTx(TxType.expense));
    expect(titleBar('খরচ যোগ করুন'), findsOneWidget);

    await tapOn(tester, find.text('সংরক্ষণ করুন'));
    expect(find.text('সঠিক পরিমাণ লিখুন'), findsOneWidget);
    expect(find.text('একটি নাম লিখুন'), findsOneWidget);
    expect(find.text('একটি ক্যাটাগরি বেছে নিন'), findsOneWidget);
    expect(find.text('লাল চিহ্নিত ঘরগুলো ঠিক করুন'), findsOneWidget);
    expect(titleBar('খরচ যোগ করুন'), findsOneWidget);
    expect((await db.financeDao.transactionsIn()).length, before);

    // Typing clears that field's error.
    await typeInto(tester, 'পরিমাণ (৳)', '0');
    await tapOn(tester, find.text('সংরক্ষণ করুন'));
    expect(find.text('সঠিক পরিমাণ লিখুন'), findsOneWidget); // zero is not an amount
    await typeInto(tester, 'পরিমাণ (৳)', '50');
    expect(find.text('সঠিক পরিমাণ লিখুন'), findsNothing);
  });

  testWidgets('a new category from the form is selected and listed on Categories', (tester) async {
    await pumpApp(tester, sampleData: true, size: kTallPhone);
    await openRoute(tester, Routes.newTx(TxType.income));
    await tapOn(tester, find.widgetWithText(DLChip, 'নতুন ক্যাটাগরি'));
    await tapOn(tester, find.text('যোগ করুন')); // empty name
    expect(find.text('একটি নাম লিখুন'), findsOneWidget);
    await typeInto(tester, 'ক্যাটাগরির নাম', 'টিউশন');
    await tapOn(tester, find.text('যোগ করুন'));
    expect(find.text('ক্যাটাগরি যোগ হয়েছে'), findsOneWidget);
    final chip = tester.widget<DLChip>(find.widgetWithText(DLChip, 'টিউশন'));
    expect(chip.selected, isTrue);

    await openRoute(tester, Routes.categories);
    await scrollTo(tester, find.text('টিউশন'));
    expect(find.text('নিজস্ব'), findsWidgets); // custom tag
    await tapOn(tester, find.descendant(of: find.widgetWithText(DLListRow, 'টিউশন'), matching: find.byTooltip('মুছে ফেলুন')));
    expect(find.text('মুছে ফেলুন?'), findsOneWidget);
    await tapOn(tester, find.text('মুছে ফেলুন').last);
    expect(find.text('ক্যাটাগরি মুছে ফেলা হয়েছে'), findsOneWidget);
    expect(find.text('টিউশন'), findsNothing);
  });

  testWidgets('search matches title and category name; filters show as removable chips', (tester) async {
    await pumpApp(tester, sampleData: true, size: kTallPhone);
    await openFinance(tester);
    expect(find.text('১২টি লেনদেন'), findsOneWidget);

    await tester.enterText(find.descendant(of: find.byType(DLSearchBar), matching: find.byType(EditableText)), 'চিকিৎসা');
    await tester.pumpAndSettle();
    expect(find.text('১টি লেনদেন'), findsOneWidget);
    await scrollTo(tester, find.text('ওষুধ'));
    expect(listedTitles(tester), ['ওষুধ']);
    await tester.enterText(find.descendant(of: find.byType(DLSearchBar), matching: find.byType(EditableText)), '');
    await tester.pumpAndSettle();

    // Filter sheet: bKash in the last 7 days.
    await tapOn(tester, find.byTooltip('ফিল্টার'));
    await tapOn(tester, find.widgetWithText(DLChip, 'শেষ ৭ দিন'));
    await tapOn(tester, find.widgetWithText(DLChip, 'বিকাশ'));
    await tapOn(tester, find.text('প্রয়োগ করুন'));
    final filter = containerOf(tester).read(finFilterProvider);
    expect((filter.range, filter.method, filter.activeCount), (FinRange.last7, PaymentMethod.bkash, 2));
    expect(find.descendant(of: find.byType(DLBadge), matching: find.text('২')), findsOneWidget);
    expect(find.text('৪টি লেনদেন'), findsOneWidget); // website, commute, internet, money home

    // Removing a chip drops that filter.
    await tapOn(tester, find.widgetWithText(DLChip, 'বিকাশ'));
    expect(containerOf(tester).read(finFilterProvider).method, isNull);

    // Nothing matches → "Clear filters" resets everything.
    await tester.enterText(find.descendant(of: find.byType(DLSearchBar), matching: find.byType(EditableText)), 'zzz');
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('এই ফিল্টারে কোনো লেনদেন নেই'));
    await tapOn(tester, find.text('ফিল্টার মুছুন'));
    expect(containerOf(tester).read(finFilterProvider).activeCount, 0);
    expect(find.text('zzz'), findsNothing);
    expect(find.text('১২টি লেনদেন'), findsOneWidget);
  });

  testWidgets('month switcher stops at the current month and the month sheet picks a month', (tester) async {
    await pumpApp(tester, sampleData: true, size: kTallPhone);
    await openFinance(tester);
    final next = tester.widget<DLIconButton>(find.widgetWithIcon(DLIconButton, DLIcons.chevronRight));
    expect(next.onPressed, isNull);

    await tapOn(tester, find.byTooltip('আগের মাস'));
    expect(find.text('অক্টোবর ২০২৬'), findsOneWidget);

    await tapOn(tester, find.text('অক্টোবর ২০২৬'));
    expect(find.text('মাস বেছে নিন'), findsOneWidget);
    await tapOn(tester, find.text('নভেম্বর ২০২৬'));
    expect(containerOf(tester).read(selectedMonthProvider), DateTime(2026, 11));
  });

  testWidgets('deleting a transaction asks first, then removes it', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTallPhone);
    await openRoute(tester, Routes.tx('t6'));
    expect(find.text('সিনেমা'), findsOneWidget);
    expect(find.text('১ নভেম্বর, রবিবার, ২০২৬'), findsOneWidget);

    await tapOn(tester, find.byTooltip('মুছে ফেলুন'));
    expect(find.text('লেনদেনটি মুছে ফেলবেন?'), findsOneWidget);
    await tapOn(tester, find.text('বাতিল'));
    expect(await db.financeDao.transactionById('t6'), isNotNull);

    await tapOn(tester, find.byTooltip('মুছে ফেলুন'));
    await tapOn(tester, find.text('মুছে ফেলুন').last);
    expect(find.text('লেনদেন মুছে ফেলা হয়েছে'), findsOneWidget);
    expect(await db.financeDao.transactionById('t6'), isNull);
  });

  testWidgets('a shop payment links to its shop; editing keeps the other details', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTallPhone);
    await openRoute(tester, Routes.tx('t11'));
    await tapOn(tester, find.text('মায়ের দোয়া স্টোর'));
    expect(titleBar('মায়ের দোয়া স্টোর'), findsOneWidget);

    await openRoute(tester, Routes.tx('t4'));
    await tapOn(tester, find.byTooltip('সম্পাদনা করুন'));
    expect(titleBar('লেনদেন সম্পাদনা'), findsOneWidget);
    expect(find.byType(DLSegmentedTabs<TxType>), findsNothing); // the type is fixed when editing
    expect(find.text('বাসা ভাড়া'), findsWidgets);
    await typeInto(tester, 'পরিমাণ (৳)', '12000');
    await tapOn(tester, find.text('সংরক্ষণ করুন'));
    expect(find.text('লেনদেন হালনাগাদ হয়েছে'), findsOneWidget);
    expect(titleBar('লেনদেনের বিবরণ'), findsOneWidget);
    expect(find.text('−৳১২,০০০'), findsOneWidget);
    final x = (await db.financeDao.transactionById('t4'))!;
    expect((x.amount, x.title, x.categoryId, x.paymentMethod, x.date), (12000, 'বাসা ভাড়া', 'rent', PaymentMethod.bank, DateTime(2026, 11, 2)));
  });

  testWidgets('savings: withdrawing more than saved is blocked; a deposit adds to the total', (tester) async {
    await pumpApp(tester, sampleData: true, size: kTallPhone);
    await openRoute(tester, Routes.savings);
    expect(find.text('৳১,২৫,০০০'), findsOneWidget);

    await tapOn(tester, find.widgetWithText(DLButton, 'তুলুন'));
    await typeInto(tester, 'পরিমাণ (৳)', '200000');
    await tapOn(tester, find.text('সংরক্ষণ করুন'));
    expect(find.text('সঞ্চয়ের চেয়ে বেশি তোলা যাবে না'), findsOneWidget);
    await tapOn(tester, find.text('বাতিল'));

    await tapOn(tester, find.widgetWithText(DLButton, 'জমা দিন'));
    await typeInto(tester, 'পরিমাণ (৳)', '5000');
    await tapOn(tester, find.text('সংরক্ষণ করুন'));
    expect(find.text('সঞ্চয় হালনাগাদ হয়েছে'), findsOneWidget);
    expect(find.text('৳১,৩০,০০০'), findsOneWidget);

    await tapOn(tester, find.text('সঞ্চয়ের ইতিহাস'));
    expect(find.text('+৳৫,০০০'), findsOneWidget);
  });

  testWidgets('an empty database shows every empty state with its action', (tester) async {
    await pumpApp(tester, size: kTallPhone);
    await openFinance(tester);
    await scrollTo(tester, find.text('এখনো কোনো লেনদেন যোগ করা হয়নি।'));
    expect(find.widgetWithText(DLButton, 'আয় যোগ করুন'), findsOneWidget);
    await tapOn(tester, find.widgetWithText(DLButton, 'খরচ যোগ করুন'));
    expect(titleBar('খরচ যোগ করুন'), findsOneWidget);
    await tapOn(tester, find.byTooltip('বন্ধ করুন'));

    await openRoute(tester, Routes.shops);
    expect(find.text('কোনো দোকানের বাকি নেই'), findsOneWidget);
    await tapOn(tester, find.widgetWithText(DLButton, 'দোকান যোগ করুন'));
    await typeInto(tester, 'দোকানের নাম', 'করিম স্টোর');
    await typeInto(tester, 'শুরুর বাকি (ঐচ্ছিক)', '700');
    await tapOn(tester, find.text('সংরক্ষণ করুন'));
    expect(find.text('দোকান যোগ হয়েছে'), findsOneWidget);
    expect(find.text('করিম স্টোর'), findsOneWidget);
    expect(find.text('৳৭০০'), findsNWidgets(2)); // total and the shop's balance

    await openRoute(tester, Routes.salary);
    expect(find.text('এখনো কোনো লেনদেন নেই'), findsOneWidget);

    await openRoute(tester, Routes.savings);
    expect(find.text('এখনো কোনো সঞ্চয়ের লক্ষ্য নেই'), findsOneWidget);
    await tapOn(tester, find.text('সঞ্চয়ের ইতিহাস'));
    expect(find.text('এখনো কোনো সঞ্চয় নেই'), findsOneWidget);
  });

  for (final (name, prefs) in [
    ('English + Dark', {PrefKeys.lang: 'en', PrefKeys.digits: 'en', PrefKeys.themeMode: 'dark'}),
    ('Bengali + Light', <String, Object>{}),
  ]) {
    testWidgets('every step 4 screen and sheet lays out on a 360dp phone ($name)', (tester) async {
      // Tall enough to build whole lists at once; the narrow width is the test.
      await pumpApp(tester, prefs: prefs, sampleData: true, size: const Size(360, 2400));
      final en = prefs.isNotEmpty;

      await tester.tap(navLabel(en ? 'Finance' : 'হিসাব'));
      await tester.pumpAndSettle();
      expect(find.byType(TxRow), findsNWidgets(12));
      for (final sheet in [en ? 'Add' : 'যোগ করুন', en ? 'Filters' : 'ফিল্টার']) {
        await tapOn(tester, find.byTooltip(sheet));
        await tester.tapAt(const Offset(180, 20)); // scrim closes the sheet
        await tester.pumpAndSettle();
      }

      for (final route in [
        Routes.tx('t11'),
        Routes.newTx(TxType.income),
        Routes.newTx(TxType.expense),
        Routes.editTx('t4'),
        Routes.categories,
        Routes.salary,
        Routes.addSalary,
        Routes.allocation,
        Routes.savings,
        Routes.shops,
        Routes.shop('s1'),
        Routes.reports,
      ]) {
        await openRoute(tester, route);
        expect(tester.takeException(), isNull, reason: route);
        containerOf(tester).read(routerProvider).pop();
        await tester.pumpAndSettle();
      }

      await openRoute(tester, Routes.shop('s1'));
      await tapOn(tester, find.widgetWithText(DLButton, en ? 'Payment' : 'পরিশোধ'));
      expect(find.byType(DLSheet), findsOneWidget);
    });
  }
}
