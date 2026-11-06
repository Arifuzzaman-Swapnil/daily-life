// Acceptance journeys 2–5 from the brief (build step 4), on the sample data in
// Bengali. The Home part of journey 3 ("Dashboard totals and recent list
// update") follows with the dashboard in step 5.
import 'package:dailylife/core/db/app_database.dart';
import 'package:dailylife/core/widgets/dl_widgets.dart';
import 'package:dailylife/features/finance/finance_screen.dart';
import 'package:dailylife/features/finance/money_providers.dart';
import 'package:flutter/widgets.dart' show Text;
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Diagnostics while chasing a stale hero after returning from two pages deep.
Future<void> dumpHero(WidgetTester tester, String when) async {
  final texts = [
    for (final w in tester.widgetList<Text>(find.descendant(of: find.byType(DLBalanceHero), matching: find.byType(Text)))) w.data,
  ];
  final totals = containerOf(tester).read(monthTotalsProvider(DateTime(2026, 11)));
  // ignore: avoid_print
  print('HERO[$when] texts=$texts provider=${totals.value?.available} ${totals.runtimeType} loading=${totals.isLoading}');
}

/// The Finance hero's remaining / income / expense figures.
void expectHero(String remaining, String income, String expense) {
  final hero = find.byType(DLBalanceHero);
  expect(find.descendant(of: hero, matching: find.text(remaining)), findsOneWidget, reason: 'remaining');
  expect(find.descendant(of: hero, matching: find.text(income)), findsOneWidget, reason: 'income');
  expect(find.descendant(of: hero, matching: find.text(expense)), findsOneWidget, reason: 'expense');
}

Future<void> openFinance(WidgetTester tester) async {
  await tester.tap(navLabel('হিসাব'));
  await tester.pumpAndSettle();
  expect(titleBar('হিসাব'), findsOneWidget);
}

void main() {
  testWidgets('journey 2: Finance → Add income → Save → top of the list, Income tab, toast', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTallPhone);
    await openFinance(tester);
    expectHero('৳১৭,১২০', '৳৫০,০০০', '৳২২,৮৮০');

    await tapOn(tester, find.byTooltip('যোগ করুন'));
    await tapOn(tester, find.text('আয় যোগ করুন'));
    expect(titleBar('আয় যোগ করুন'), findsOneWidget);

    await typeInto(tester, 'পরিমাণ (৳)', '২৫০০'); // Bengali digits are accepted.
    await typeInto(tester, 'আয়ের নাম', 'বোনাস পেমেন্ট');
    await tapOn(tester, find.widgetWithText(DLChip, 'বোনাস'));
    await tapOn(tester, find.text('সংরক্ষণ করুন'));

    expect(find.text('আয় সংরক্ষণ হয়েছে'), findsOneWidget);
    expect(titleBar('হিসাব'), findsOneWidget);
    expect(containerOf(tester).read(finFilterProvider).tab, FinTab.income);
    final rows = tester.widgetList<TxRow>(find.byType(TxRow)).toList();
    expect(rows.first.x.title, 'বোনাস পেমেন্ট');
    expect(rows.every((r) => r.x.type == TxType.income), isTrue);
    expect(find.text('+৳২,৫০০'), findsOneWidget);
    expectHero('৳১৯,৬২০', '৳৫২,৫০০', '৳২২,৮৮০');

    final saved = (await db.financeDao.transactionsIn()).firstWhere((x) => x.title == 'বোনাস পেমেন্ট');
    expect((saved.amount, saved.categoryId, saved.paymentMethod, saved.date), (2500, 'bonus', PaymentMethod.bank, DateTime(2026, 11, 6)));
  });

  testWidgets('journey 3: Add expense with a budget category → Finance totals update', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTallPhone);
    await openFinance(tester);

    await tapOn(tester, find.byTooltip('যোগ করুন'));
    await tapOn(tester, find.text('খরচ যোগ করুন'));
    await typeInto(tester, 'পরিমাণ (৳)', '1000');
    await typeInto(tester, 'খরচের শিরোনাম', 'নতুন বই');
    await tapOn(tester, find.widgetWithText(DLChip, 'কেনাকাটা'));
    await tapOn(tester, find.byType(DLSelect<String?>));
    await tapOn(tester, find.text('ব্যক্তিগত খরচ').last);
    await tapOn(tester, find.text('সংরক্ষণ করুন'));

    expect(find.text('খরচ সংরক্ষণ হয়েছে'), findsOneWidget);
    expect(containerOf(tester).read(finFilterProvider).tab, FinTab.expense);
    expectHero('৳১৬,১২০', '৳৫০,০০০', '৳২৩,৮৮০');
    await scrollTo(tester, find.text('নতুন বই'));
    expect(find.text('−৳১,০০০'), findsOneWidget);

    final saved = (await db.financeDao.transactionsIn()).firstWhere((x) => x.title == 'নতুন বই');
    expect((saved.type, saved.amount, saved.categoryId, saved.allocationId), (TxType.expense, 1000, 'shopping', 'a5'));

    // The details show the budget category.
    await tapOn(tester, find.text('নতুন বই'));
    expect(titleBar('লেনদেনের বিবরণ'), findsOneWidget);
    expect(find.text('ব্যক্তিগত খরচ'), findsOneWidget);
    expect(find.text('−৳১,০০০'), findsOneWidget);
  });

  testWidgets('journey 4: Salary → Add salary → income recorded → Allocate → over-allocation warning', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTallPhone);
    await openFinance(tester);

    await tapOn(tester, find.text('বেতন ব্যবস্থাপনা'));
    expect(titleBar('বেতন ব্যবস্থাপনা'), findsOneWidget);
    expect(find.text('৳৪০,০০০'), findsWidgets);

    await tapOn(tester, find.widgetWithText(DLButton, 'বেতন যোগ করুন'));
    expect(fieldLabelled('পরিমাণ (৳)'), findsOneWidget);
    expect(find.text('40000'), findsOneWidget); // starts from the monthly salary
    await typeInto(tester, 'পরিমাণ (৳)', '45000');
    await tapOn(tester, find.text('সংরক্ষণ করুন'));

    expect(find.text('বেতন যোগ হয়েছে'), findsOneWidget);
    expect(titleBar('বেতন ব্যবস্থাপনা'), findsOneWidget);
    expect(find.text('৳৪৫,০০০'), findsNWidgets(2)); // monthly and last salary
    expect(find.text('নভেম্বর ২০২৬-এর বেতন'), findsOneWidget);
    expect(find.text('বৃদ্ধি +৳৫,০০০'), findsOneWidget);

    final income = (await db.financeDao.transactionsIn()).where((x) => x.categoryId == 'salary' && x.amount == 45000).single;
    expect((income.type, income.title, income.date), (TxType.income, 'নভেম্বর-এর বেতন', DateTime(2026, 11, 6)));

    // Allocate: 40,000 of the new 45,000 is allocated; raising rent to 20,000
    // over-allocates by 5,000.
    await tapOn(tester, find.text('বেতন বণ্টন করুন'));
    expect(titleBar('বেতন বণ্টন'), findsOneWidget);
    expect(find.text('৳৫,০০০'), findsOneWidget); // unallocated
    await tester.enterText(find.text('10000').first, '20000'); // the rent row's budget
    await tester.pumpAndSettle();
    expect(find.text('বেতনের চেয়ে ৳৫,০০০ বেশি বণ্টন হয়েছে'), findsOneWidget);
    expect((await db.salaryDao.allocations()).firstWhere((a) => a.id == 'a1').amount, 20000);

    // Back on Finance the salary is in this month's income.
    await tapOn(tester, find.byTooltip('পেছনে যান'));
    await tapOn(tester, find.byTooltip('পেছনে যান'));
    await dumpHero(tester, 'j4 back');
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await dumpHero(tester, 'j4 +3s');
    expectHero('৳৬২,১২০', '৳৯৫,০০০', '৳২২,৮৮০');
  });

  testWidgets('journey 5: Shop credit → purchase → partial payment; overpay blocked', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTallPhone);
    await openFinance(tester);

    await tapOn(tester, find.text('দোকানের বাকি').first);
    expect(titleBar('দোকানের বাকি'), findsOneWidget);
    await tapOn(tester, find.text('মায়ের দোয়া স্টোর'));
    expect(titleBar('মায়ের দোয়া স্টোর'), findsOneWidget);
    expect(find.text('৳১,০০০'), findsNWidgets(2)); // now due, top and bottom
    expect(find.text('৳১,২০০'), findsOneWidget); // previous balance

    // A credit purchase raises the balance and is not an expense.
    await tapOn(tester, find.widgetWithText(DLButton, 'কেনাকাটা যোগ করুন'));
    await typeInto(tester, 'পরিমাণ (৳)', '300');
    await typeInto(tester, 'কী কিনলেন', 'চিনি');
    await tapOn(tester, find.text('সংরক্ষণ করুন'));
    expect(find.text('কেনাকাটা যোগ হয়েছে'), findsOneWidget);
    expect(find.text('৳১,৩০০'), findsNWidgets(2));
    expect(find.text('চিনি'), findsOneWidget);
    expect((await db.financeDao.transactionsIn()).where((x) => x.shopId == 's1'), hasLength(1));

    // Paying more than is owed is blocked.
    await tapOn(tester, find.widgetWithText(DLButton, 'পরিশোধ'));
    expect(find.text('এখন বাকি: ৳১,৩০০'), findsOneWidget);
    await typeInto(tester, 'পরিমাণ (৳)', '2000');
    await tapOn(tester, find.text('সংরক্ষণ করুন'));
    expect(find.text('বাকির চেয়ে বেশি পরিশোধ করা যাবে না'), findsOneWidget);

    // A partial payment lowers the balance and records an expense.
    await typeInto(tester, 'পরিমাণ (৳)', '500');
    await tapOn(tester, find.text('সংরক্ষণ করুন'));
    expect(find.text('পরিশোধ যোগ হয়েছে'), findsOneWidget);
    expect(find.text('৳৮০০'), findsNWidgets(2));
    final firstRow = find.byType(DLListRow).first;
    expect(find.descendant(of: firstRow, matching: find.text('আংশিক পরিশোধ')), findsOneWidget);
    expect(find.descendant(of: firstRow, matching: find.text('বাকি ৳৮০০')), findsOneWidget);

    final payments = (await db.financeDao.transactionsIn()).where((x) => x.shopId == 's1').toList();
    expect(payments, hasLength(2));
    expect((payments.first.amount, payments.first.categoryId, payments.first.title), (500, 'shop', 'মায়ের দোয়া স্টোর-এ পরিশোধ'));

    // The expense shows on Finance.
    await tapOn(tester, find.byTooltip('পেছনে যান'));
    await tapOn(tester, find.byTooltip('পেছনে যান'));
    expect(titleBar('হিসাব'), findsOneWidget);
    await dumpHero(tester, 'j5 back');
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await dumpHero(tester, 'j5 +3s');
    expectHero('৳১৬,৬২০', '৳৫০,০০০', '৳২৩,৩৮০');
    await scrollTo(tester, find.text('মায়ের দোয়া স্টোর-এ পরিশোধ'));
  });
}
