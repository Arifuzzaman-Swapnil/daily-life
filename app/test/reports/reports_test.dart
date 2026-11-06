// Build step 6.6: Reports (prototype `reports`, screenshots 70–73) on the
// sample data in Bengali with the pinned clock (November 2026).
import 'package:dailylife/core/widgets/dl_widgets.dart';
import 'package:dailylife/features/reports/reports_providers.dart';
import 'package:dailylife/features/reports/reports_screen.dart';
import 'package:dailylife/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

const kTall = Size(393, 3000);

void main() {
  testWidgets('financial: KPIs, income vs expenses, categories, salary, month / year (screen 70)', (tester) async {
    await pumpApp(tester, sampleData: true, size: kTall);
    await openRoute(tester, Routes.reports);
    expect(titleBar('রিপোর্ট ও বিশ্লেষণ'), findsOneWidget);
    expect(find.text('নভেম্বর ২০২৬'), findsOneWidget);
    for (final v in ['৳৫০,০০০', '৳১৭,১২০', 'সঞ্চয়ের হার ২০%']) {
      expect(find.text(v), findsOneWidget, reason: v);
    }
    expect(find.text('৳২২,৮৮০'), findsNWidgets(2)); // KPI and the donut's total
    expect(find.text('নভেম্বর ২০২৬: +৳৫০,০০০ / −৳২২,৮৮০'), findsOneWidget);
    expect(find.text('নিট ৳২৭,১২০'), findsOneWidget);
    expect(tester.widget<DLBarChart>(find.byType(DLBarChart)).groups, hasLength(6));
    expect(find.byType(DLDonut), findsOneWidget);
    expect(find.text('অক্টোবর ২০২৬-এর বেতন'), findsOneWidget); // the latest salary: October's, paid 1 November
    expect(find.text('৳১,৮৫০'), findsOneWidget);

    // The current month is the latest; October is one back.
    expect(tester.widget<DLIconButton>(find.widgetWithIcon(DLIconButton, DLIcons.chevronRight)).onPressed, isNull);
    await tapOn(tester, find.byTooltip('আগের মাস'));
    expect(find.text('অক্টোবর ২০২৬'), findsOneWidget);
    expect(find.text('৳৪৭,৫০০'), findsOneWidget);

    await tapOn(tester, find.text('বছর'));
    expect(find.text('২০২৬'), findsOneWidget);
    expect(tester.widget<DLBarChart>(find.byType(DLBarChart)).groups, hasLength(12));

    // Export shares a CSV.
    await tapOn(tester, find.byTooltip('এক্সপোর্ট করুন'));
    expect(find.text('CSV ফাইল এক্সপোর্ট হয়েছে'), findsOneWidget);
    expect(filesOf(tester).shared.single, startsWith('daily-life-fin-2026.csv'));
  });

  testWidgets('productivity: tasks, hours, active days, projects, week (screen 71)', (tester) async {
    await pumpApp(tester, sampleData: true, size: kTall);
    await openRoute(tester, Routes.reportsTab(ReportTab.prod));
    expect(find.text('৭'), findsOneWidget); // completed
    expect(find.text('৪'), findsOneWidget); // pending
    expect(find.text('২৮ ঘ ৪৫ মি'), findsNWidgets(2)); // KPI and this week's total
    expect(find.text('দৈনিক গড় ৫ ঘ ৪৫ মি'), findsOneWidget);
    expect(find.text('১৩ ঘ ৪৫ মি'), findsOneWidget); // Baselinq
    expect(find.text('৬টি কাজ · ৪টি সম্পন্ন'), findsOneWidget);
  });

  testWidgets('lifestyle: water, habits, the last 7 days (screen 72)', (tester) async {
    await pumpApp(tester, sampleData: true, size: kTall);
    await openRoute(tester, Routes.reports);
    await tapOn(tester, find.text('জীবনযাপন'));
    expect(find.text('২,৫৩৬ মিলি'), findsOneWidget);
    expect(find.text('৩ দিন/৭'), findsOneWidget);
    expect(find.text('৩ দিন / ৭'), findsOneWidget);
    expect(find.text('৬৭%'), findsOneWidget);
    expect(find.text('৭/৭'), findsOneWidget);
    final chart = tester.widget<DLBarChart>(find.byType(DLBarChart));
    expect(chart.groups.map((g) => g.values.single), [2400, 3000, 2750, 3200, 1900, 3000, 1500]);
    expect(find.text('আজ'), findsOneWidget);
    expect(find.text('গতকাল'), findsOneWidget);
  });

  testWidgets('Work history opens the productivity report', (tester) async {
    await pumpApp(tester, sampleData: true, size: kTall);
    await openRoute(tester, Routes.workHistory);
    await tapOn(tester, find.byTooltip('উৎপাদনশীলতা'));
    expect(tester.widget<ReportsScreen>(find.byType(ReportsScreen)).tab, ReportTab.prod);
  });

  testWidgets('no data: zero figures and an empty category breakdown (screen 73 loads first)', (tester) async {
    await pumpApp(tester, size: kTall);
    await openRoute(tester, Routes.reports);
    expect(find.text('এখনো কোনো লেনদেন যোগ করা হয়নি।'), findsWidgets);
    expect(find.byType(DLSkeleton), findsNothing);
  });
}
