// Build step 6.6: Documents (prototype `docs`, `docDetail`, `docImport`;
// screenshots 66–68 and 95) on the sample data in Bengali. File picking,
// storage and sharing go through the fake file service.
import 'package:dailylife/core/db/app_database.dart';
import 'package:dailylife/core/files/file_service.dart';
import 'package:dailylife/core/widgets/dl_widgets.dart';
import 'package:dailylife/features/documents/documents_screen.dart';
import 'package:dailylife/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

const kTall = Size(393, 2400);

void main() {
  testWidgets('documents: categories with counts, list, filter and search (screen 66)', (tester) async {
    await pumpApp(tester, sampleData: true, size: kTall);
    await openRoute(tester, Routes.documents);
    expect(titleBar('ডকুমেন্ট'), findsOneWidget);
    expect(find.text('৬টি ফাইল'), findsOneWidget);
    expect(find.text('অফিস · ৩ ফেব্রু ২০২৬ · ২৪০ KB'), findsOneWidget);
    expect(find.text('শিক্ষা · ১৪ সেপ্টে ২০২৫ · ১.২ MB'), findsOneWidget);
    expect(find.byType(DLListRow), findsNWidgets(6));

    await tapOn(tester, find.text('আর্থিক'));
    expect(find.text('২টি ফাইল'), findsOneWidget);
    expect(find.byType(DLListRow), findsNWidgets(2));
    // Tapping the selected category again shows everything.
    await tapOn(tester, find.text('আর্থিক').first);
    expect(find.byType(DLListRow), findsNWidgets(6));

    await tester.enterText(find.descendant(of: find.byType(DLSearchBar), matching: find.byType(EditableText)), 'ভাড়া');
    await tester.pumpAndSettle();
    expect(find.text('বাসা ভাড়ার চুক্তি'), findsOneWidget);
    expect(find.byType(DLListRow), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byType(DLSearchBar), matching: find.byType(EditableText)), 'নেই');
    await tester.pumpAndSettle();
    expect(find.text('কিছু পাওয়া যায়নি'), findsOneWidget);
  });

  testWidgets('document details: preview, facts, share, delete (screen 67)', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTall);
    await openRoute(tester, Routes.document('d1'));
    expect(titleBar('ডকুমেন্টের বিবরণ'), findsOneWidget);
    expect(find.text('৩ পৃষ্ঠা'), findsOneWidget);
    for (final v in ['অফিস', 'PDF', '২৪০ KB', '৩ ফেব্রু ২০২৬', 'ব্যাকএন্ড এআই ইঞ্জিনিয়ার পদ']) {
      expect(find.widgetWithText(DLKeyValueRow, v), findsOneWidget, reason: v);
    }

    await tapOn(tester, find.widgetWithText(DLButton, 'শেয়ার করুন'));
    expect(filesOf(tester).shared.single, startsWith('অফার লেটার — Intelleqt'));

    await tapOn(tester, find.byTooltip('মুছে ফেলুন'));
    expect(find.text('ডকুমেন্টটি মুছে ফেলবেন?'), findsOneWidget);
    await tapOn(tester, find.descendant(of: find.byType(DLConfirmDialog), matching: find.text('মুছে ফেলুন')));
    expect(find.text('ডকুমেন্ট মুছে ফেলা হয়েছে'), findsOneWidget);
    expect(await db.documentsDao.documentById('d1'), isNull);
  });

  testWidgets('import: a file and a title are required; the copy is stored (screen 68)', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTall);
    await openRoute(tester, Routes.documents);
    await tapOn(tester, find.byTooltip('ডকুমেন্ট যোগ করুন'));
    expect(find.byType(ImportDocumentScreen), findsOneWidget);

    await tapOn(tester, find.text('সংরক্ষণ করুন'));
    expect(find.text('একটি ফাইল বেছে নিন'), findsOneWidget);
    expect(find.text('একটি নাম লিখুন'), findsOneWidget);

    await tapOn(tester, find.text('ফাইল বেছে নিন · PDF'));
    expect(find.text('scan_2026-11-06.pdf'), findsOneWidget);
    expect(find.text('একটি ফাইল বেছে নিন'), findsNothing);
    await typeInto(tester, 'শিরোনাম', 'বিদ্যুৎ বিলের রসিদ');
    await tapOn(tester, find.widgetWithText(DLChip, 'আর্থিক'));
    await tapOn(tester, find.text('সংরক্ষণ করুন'));

    expect(find.text('ডকুমেন্ট যোগ হয়েছে'), findsOneWidget);
    expect(find.byType(DocumentsScreen), findsOneWidget);
    expect(find.text('৭টি ফাইল'), findsOneWidget);
    expect(find.text('আর্থিক · ৬ নভে ২০২৬ · ৭৮০ KB'), findsOneWidget);
    final d = (await db.select(db.documents).get()).singleWhere((d) => d.title == 'বিদ্যুৎ বিলের রসিদ');
    expect((d.kind, d.category, d.pages, d.sizeBytes, d.filePath), (DocKind.pdf, DocCategory.fin, 2, 798720, '/app/documents/${d.id}'));
    expect(filesOf(tester).stored, [d.id]);
  });

  testWidgets('an image import counts one page; cancelling the picker keeps the form empty', (tester) async {
    final db = await pumpApp(tester, size: kTall);
    await openRoute(tester, Routes.importDoc);
    filesOf(tester).next = (_) => null; // cancelled
    await tapOn(tester, find.text('ফাইল বেছে নিন · ছবি'));
    expect(find.text('IMG_20261106_1042.jpg'), findsNothing);
    filesOf(tester).next = (_) => const PickedFile(path: '/picked/nid.jpg', name: 'nid.jpg', size: 2048);
    await tapOn(tester, find.text('ফাইল বেছে নিন · ছবি'));
    await typeInto(tester, 'শিরোনাম', 'জাতীয় পরিচয়পত্র');
    await tapOn(tester, find.text('সংরক্ষণ করুন'));
    final d = (await db.select(db.documents).get()).single;
    expect((d.kind, d.pages, d.sizeBytes), (DocKind.img, 1, 2048));
  });

  testWidgets('no documents: empty state with an import button (screen 95)', (tester) async {
    await pumpApp(tester, size: kTall);
    await openRoute(tester, Routes.documents);
    expect(find.text('কোনো ডকুমেন্ট নেই'), findsOneWidget);
    expect(find.text('০টি ফাইল'), findsOneWidget);
    await tapOn(tester, find.widgetWithText(DLButton, 'ডকুমেন্ট যোগ করুন'));
    expect(find.byType(ImportDocumentScreen), findsOneWidget);
  });
}
