// Build step 6.3: the Notebook (prototype `notes`, `noteEdit`, `noteDetail`;
// screenshots 55–57 and 93) and acceptance journey 9, on the sample data in
// Bengali with the pinned clock (Friday 2026-11-06).
import 'package:dailylife/core/widgets/dl_widgets.dart';
import 'package:dailylife/features/notes/note_editor_screen.dart';
import 'package:dailylife/features/notes/notes_providers.dart';
import 'package:dailylife/features/notes/notes_screen.dart';
import 'package:dailylife/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// The editor's title (0) and body (1) inputs.
Finder editorField(int i) => find.descendant(of: find.byType(NoteEditorScreen), matching: find.byType(TextField)).at(i);

void main() {
  testWidgets('Notebook: pinned and other notes, search, categories, archive (screen 55)', (tester) async {
    await pumpApp(tester, sampleData: true, size: kTallPhone);
    await openRoute(tester, Routes.notes);
    expect(titleBar('নোটবুক'), findsOneWidget);
    expect(find.text('পিন করা'), findsOneWidget);
    expect(find.text('অন্যান্য নোট'), findsOneWidget);
    for (final title in ['ক্লায়েন্ট ডেমোর পয়েন্ট', 'ডিসেম্বরের বাজেট পরিকল্পনা', 'পড়ার তালিকা', 'অ্যাপের নতুন আইডিয়া', 'ভিসা কাগজপত্রের তালিকা']) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    expect(find.text('পুরনো মিটিং নোট'), findsNothing);
    expect(find.text('৬ নভে'), findsOneWidget);
    expect(find.byIcon(DLIcons.pin), findsNWidgets(3)); // section icon + 2 pinned cards

    await tester.enterText(find.descendant(of: find.byType(DLSearchBar), matching: find.byType(EditableText)), 'বাজেট');
    await tester.pumpAndSettle();
    expect(find.text('ডিসেম্বরের বাজেট পরিকল্পনা'), findsOneWidget);
    expect(find.text('পড়ার তালিকা'), findsNothing);
    await tester.enterText(find.descendant(of: find.byType(DLSearchBar), matching: find.byType(EditableText)), 'কিছুই না');
    await tester.pumpAndSettle();
    expect(find.text('কিছু পাওয়া যায়নি'), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byType(DLSearchBar), matching: find.byType(EditableText)), '');
    await tester.pumpAndSettle();

    await tapOn(tester, find.widgetWithText(DLChip, 'আইডিয়া'));
    expect(find.text('অ্যাপের নতুন আইডিয়া'), findsOneWidget);
    expect(find.text('পড়ার তালিকা'), findsNothing);
    await tapOn(tester, find.widgetWithText(DLChip, 'সব'));

    await tapOn(tester, find.byTooltip('আর্কাইভ'));
    expect(containerOf(tester).read(noteFilterProvider).archived, isTrue);
    expect(find.text('পুরনো মিটিং নোট'), findsOneWidget);
    expect(find.text('পড়ার তালিকা'), findsNothing);
  });

  testWidgets('journey 9: More → Notebook → create (opens details) → edit → pin', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTallPhone);
    await tester.tap(navLabel('আরও'));
    await tester.pumpAndSettle();
    await tapOn(tester, find.text('নোটবুক'));
    await tapOn(tester, find.byTooltip('নতুন নোট'));
    expect(titleBar('নতুন নোট'), findsOneWidget);

    // A title or some text is required.
    await tapOn(tester, find.widgetWithText(DLButton, 'সংরক্ষণ করুন'));
    expect(find.text('শিরোনাম বা কিছু লেখা দিন'), findsOneWidget);
    // Let the error toast go: it sits over the body field.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.enterText(editorField(0), 'বাজারের তালিকা');
    await tester.enterText(editorField(1), 'চাল ডাল তেল');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(editorField(0)).controller!.text, 'বাজারের তালিকা');
    expect(find.text('৩ শব্দ'), findsOneWidget);
    await tapOn(tester, find.widgetWithText(DLChip, 'অফিস'));
    await tapOn(tester, find.widgetWithText(DLButton, 'সংরক্ষণ করুন'));

    // The new note opens on its details.
    expect(find.text('নোট সংরক্ষণ হয়েছে'), findsOneWidget);
    expect(find.text('বাজারের তালিকা'), findsOneWidget);
    expect(find.text('চাল ডাল তেল'), findsOneWidget);
    expect(find.text('অফিস'), findsOneWidget);
    expect(find.text('তৈরি ৬ নভে ২০২৬ · হালনাগাদ ৬ নভে ২০২৬'), findsOneWidget);

    await tapOn(tester, find.widgetWithText(DLButton, 'সম্পাদনা করুন'));
    expect(titleBar('নোট সম্পাদনা'), findsOneWidget);
    expect(find.text('তৈরি ৬ নভে ২০২৬'), findsOneWidget);
    await tester.enterText(editorField(1), 'চাল ডাল তেল লবণ');
    await tapOn(tester, find.widgetWithText(DLButton, 'সংরক্ষণ করুন'));
    expect(find.text('চাল ডাল তেল লবণ'), findsOneWidget);

    await tapOn(tester, find.byTooltip('পিন করুন'));
    expect(find.text('নোট পিন হয়েছে'), findsOneWidget);
    expect(find.text('পিন করা'), findsOneWidget);
    final saved = (await db.select(db.notes).get()).singleWhere((n) => n.title == 'বাজারের তালিকা');
    expect((saved.body, saved.pinned, saved.archived), ('চাল ডাল তেল লবণ', true, false));

    // Back in the notebook it is with the pinned notes.
    await tapOn(tester, find.byTooltip('পেছনে যান'));
    expect(titleBar('নোটবুক'), findsOneWidget);
    expect(find.text('বাজারের তালিকা'), findsOneWidget);
  });

  testWidgets('note details: archive unpins, restore, delete (screen 57)', (tester) async {
    final db = await pumpApp(tester, sampleData: true, size: kTallPhone);
    await openRoute(tester, Routes.note('n2'));
    expect(find.text('ক্লায়েন্ট ডেমোর পয়েন্ট'), findsOneWidget);
    expect(find.text('পিন করা'), findsOneWidget);

    await tapOn(tester, find.widgetWithText(DLButton, 'আর্কাইভ করুন'));
    expect(find.text('নোট আর্কাইভ হয়েছে'), findsOneWidget);
    var n = (await db.notesDao.noteById('n2'))!;
    expect((n.archived, n.pinned), (true, false));
    expect(find.text('আর্কাইভ'), findsOneWidget);

    await tapOn(tester, find.widgetWithText(DLButton, 'আর্কাইভ থেকে ফেরান'));
    expect(find.text('নোট ফেরত আনা হয়েছে'), findsOneWidget);
    n = (await db.notesDao.noteById('n2'))!;
    expect(n.archived, isFalse);

    await tapOn(tester, find.byTooltip('মুছে ফেলুন'));
    expect(find.text('নোটটি মুছে ফেলবেন?'), findsOneWidget);
    await tapOn(tester, find.descendant(of: find.byType(DLConfirmDialog), matching: find.text('মুছে ফেলুন')));
    expect(find.text('নোট মুছে ফেলা হয়েছে'), findsOneWidget);
    expect(await db.notesDao.noteById('n2'), isNull);
  });

  testWidgets('empty notebook and archive (screen 93)', (tester) async {
    await pumpApp(tester, size: kTallPhone);
    await openRoute(tester, Routes.notes);
    expect(find.byType(NotesScreen), findsOneWidget);
    expect(find.text('আপনার নোটবুক এখনো খালি।'), findsOneWidget);
    expect(find.text('প্রথম নোট লিখে শুরু করুন।'), findsOneWidget);
    await tapOn(tester, find.widgetWithText(DLButton, 'নতুন নোট'));
    expect(titleBar('নতুন নোট'), findsOneWidget);
    await tester.enterText(editorField(0), 'প্রথম নোট');
    await tapOn(tester, find.widgetWithText(DLButton, 'সংরক্ষণ করুন'));
    await tapOn(tester, find.widgetWithText(DLButton, 'আর্কাইভ করুন'));
    await tapOn(tester, find.byTooltip('পেছনে যান'));
    // The only note is archived: the notebook says nothing matches; the archive shows it.
    expect(find.text('কিছু পাওয়া যায়নি'), findsOneWidget);
    await tapOn(tester, find.byTooltip('আর্কাইভ'));
    expect(find.text('প্রথম নোট'), findsOneWidget);
  });
}
