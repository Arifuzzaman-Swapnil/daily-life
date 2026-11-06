// A walk through every screen of the app (tabs, pages, sheets and a dialog)
// for the switching journeys 10–12, plus what they check at each stop: the
// text on screen and the colours it is drawn in.
import 'package:dailylife/app.dart';
import 'package:dailylife/core/db/app_database.dart';
import 'package:dailylife/core/prefs/app_settings.dart';
import 'package:dailylife/core/theme/dl_tokens.dart';
import 'package:dailylife/core/widgets/dl_widgets.dart';
import 'package:dailylife/features/calendar/calendar_providers.dart';
import 'package:dailylife/features/health/health_providers.dart';
import 'package:dailylife/features/reminders/reminders_providers.dart';
import 'package:dailylife/features/reports/reports_providers.dart';
import 'package:dailylife/features/settings/appearance_cards.dart';
import 'package:dailylife/features/settings/settings_screen.dart';
import 'package:dailylife/l10n/app_localizations.dart';
import 'package:dailylife/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Tall enough that every list builds completely.
const kTourPhone = Size(393, 2400);

/// One place on the tour: [open] shows it, starting from wherever the last
/// stop left the app. An [overlay] stop (sheet, dialog) is closed afterwards.
typedef Stop = ({String name, Future<void> Function(WidgetTester tester, AppLocalizations t) open, bool overlay});

Stop _page(String location) => (name: location, open: (tester, t) => show(tester, location), overlay: false);

Stop _state(String name, String location, void Function(WidgetTester tester) set) => (
      name: name,
      open: (tester, t) async {
        await show(tester, location);
        set(tester);
        await tester.pumpAndSettle();
      },
      overlay: false,
    );

Stop _overlay(String name, String location, Finder Function(AppLocalizations t) button) => (
      name: name,
      open: (tester, t) async {
        await show(tester, location);
        await tapOn(tester, button(t));
      },
      overlay: true,
    );

/// Shows [location]: a tab with `go`, anything else pushed over Home.
Future<void> show(WidgetTester tester, String location) async {
  final router = containerOf(tester).read(routerProvider);
  final tab = Routes.tabs.contains(location);
  router.go(tab ? location : Routes.home);
  await tester.pumpAndSettle();
  if (tab) return;
  router.push(location);
  await tester.pumpAndSettle();
}

/// Every screen, with the sample data's ids.
final List<Stop> fullTour = [
  _page(Routes.home),
  _overlay('home: month sheet', Routes.home, (t) => find.descendant(of: find.byType(DLBalanceHero), matching: find.byType(DLHeroPill))),
  _overlay('home: customize sheet', Routes.home, (t) => find.text(t.customize)),
  _page(Routes.notifications),
  _page(Routes.finance),
  _overlay('finance: add sheet', Routes.finance, (t) => find.byTooltip(t.add)),
  _overlay('finance: filter sheet', Routes.finance, (t) => find.byTooltip(t.filters)),
  _page(Routes.tx('t1')),
  _overlay('transaction: delete dialog', Routes.tx('t6'), (t) => find.byTooltip(t.del)),
  _page(Routes.newTx(TxType.income)),
  _page(Routes.editTx('t4')),
  _page(Routes.categories),
  _page(Routes.salary),
  _page(Routes.addSalary),
  _page(Routes.allocation),
  _page(Routes.savings),
  _page(Routes.shops),
  _page(Routes.shop('s1')),
  for (final view in CalView.values)
    _state('calendar: ${view.name}', Routes.calendar, (tester) => containerOf(tester).read(calendarProvider.notifier).setView(view)),
  _page(Routes.event('ev1')),
  _page(Routes.newEvent),
  _page(Routes.work),
  _page(Routes.task('k1')),
  _page(Routes.newTask()),
  _page(Routes.timer),
  _page(Routes.workHistory),
  _page(Routes.projects),
  _page(Routes.project('p1')),
  _page(Routes.more),
  for (final tab in RemTab.values)
    _state('reminders: ${tab.name}', Routes.reminders, (tester) => containerOf(tester).read(remTabProvider.notifier).set(tab)),
  _page(Routes.reminder('r1')),
  _page(Routes.newReminder()),
  _page(Routes.notes),
  _page(Routes.note('n1')),
  _page(Routes.newNote),
  for (final tab in HealthTab.values) _page(Routes.healthTab(tab)),
  _page(Routes.newMeal(MealType.dinner)),
  _page(Routes.habit('h1')),
  _page(Routes.goals),
  _page(Routes.goal('gl1')),
  _page(Routes.newGoal),
  _page(Routes.documents),
  _page(Routes.document('d1')),
  _page(Routes.importDoc),
  for (final tab in ReportTab.values) _page(Routes.reportsTab(tab)),
  _page(Routes.settings),
];

/// The five tabs plus a sheet and a dialog: a quick look after a change.
final List<Stop> shortTour = [
  for (final tab in [Routes.home, Routes.finance, Routes.calendar, Routes.work, Routes.more]) _page(tab),
  fullTour.firstWhere((s) => s.name == 'finance: add sheet'),
  fullTour.firstWhere((s) => s.name == 'transaction: delete dialog'),
];

AppLocalizations currentL10n(WidgetTester tester) =>
    lookupAppLocalizations(Locale(containerOf(tester).read(settingsProvider).lang.name));

/// Walks [stops]; at each, after it has opened, calls [check] with the stop's
/// name, then closes it if it is an overlay.
Future<void> tour(WidgetTester tester, List<Stop> stops, void Function(String stop) check) async {
  for (final stop in stops) {
    await stop.open(tester, currentL10n(tester));
    expect(tester.takeException(), isNull, reason: stop.name);
    check(stop.name);
    if (stop.overlay) {
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      expect(find.byType(DLSheet), findsNothing, reason: stop.name);
    }
  }
}

/// Calls [visit] for every widget on screen (onstage), leaving out the
/// subtrees [skip] matches.
void _walk(WidgetTester tester, bool Function(Widget w) skip, void Function(Widget w) visit) {
  void walk(Element e) {
    if (skip(e.widget)) return;
    visit(e.widget);
    e.debugVisitOnstageChildren(walk);
  }

  find.byType(DailyLifeApp).evaluate().single.debugVisitOnstageChildren(walk);
}

/// Every piece of text on screen: labels, field contents, tooltips and what
/// screen readers say. Subtrees [skip] matches are left out.
List<String> screenTexts(WidgetTester tester, {bool Function(Widget w)? skip}) {
  final out = <String>[];
  void add(String? s) {
    if (s != null && s.trim().isNotEmpty) out.add(s);
  }

  _walk(tester, skip ?? (_) => false, (w) {
    switch (w) {
      case RichText():
        add(w.text.toPlainText());
      case EditableText():
        add(w.controller.text);
      case Tooltip():
        add(w.message);
      case Semantics():
        add(w.properties.label);
        add(w.properties.hint);
        add(w.properties.value);
    }
  });
  return out;
}

/// Bengali letters and digits. The taka sign (U+09F3) is used in both languages.
final bengali = RegExp(r'[ঀ-৲৴-৿]');

/// The language cards name each language in its own script on purpose.
bool skipLanguageCards(Widget w) => w is LanguageCards;

/// Paper (the document preview) and the theme miniatures keep their own
/// colours in both themes.
bool skipFixedColours(Widget w) => w is ThemeCards || w.runtimeType.toString() == '_DocPreview';

List<Color> palette(DLColors c) => [
      c.brand, c.brandHover, c.onBrand, c.onBrandAccent, c.brandMuted, c.accent, c.accentText, c.accentSoft, c.onAccent,
      c.actionPrimary, c.actionPrimaryHover, c.onActionPrimary, c.background, c.surface, c.surfaceRaised, c.surfaceSunken,
      c.textPrimary, c.textSecondary, c.textDisabled, c.divider, c.borderStrong, c.focusRing, c.scrim,
      c.success, c.successText, c.successSoft, c.onSuccess, c.warning, c.warningText, c.warningSoft,
      c.danger, c.dangerText, c.dangerSoft, c.onDanger, c.income, c.expense,
      c.catEvent, c.catTask, c.catTaskText, c.catTaskSoft, c.catReminder, c.catBill,
      c.chart1, c.chart2, c.chart3, c.chart4, c.chartGrid,
    ];

/// Colours of [theme]'s palette that the other theme doesn't have: seeing one
/// on screen in the other theme means something didn't follow the switch.
Set<int> onlyIn(Brightness theme) {
  final (mine, other) = theme == Brightness.light ? (DLColors.light, DLColors.dark) : (DLColors.dark, DLColors.light);
  return {for (final c in palette(mine)) c.toARGB32()}..removeAll(palette(other).map((c) => c.toARGB32()));
}

/// Every colour drawn on screen (fills, borders, text), with what drew it.
List<(String, Color)> screenColours(WidgetTester tester) {
  final out = <(String, Color)>[];
  void add(Widget w, Color? c) {
    if (c != null) out.add((w.runtimeType.toString(), c));
  }

  void decoration(Widget w, Decoration? d) {
    if (d is BoxDecoration) {
      add(w, d.color);
      final b = d.border;
      if (b is Border) {
        for (final s in [b.top, b.right, b.bottom, b.left]) {
          if (s.style != BorderStyle.none && s.width > 0) add(w, s.color);
        }
      }
    } else if (d is ShapeDecoration) {
      add(w, d.color);
      final shape = d.shape;
      if (shape is OutlinedBorder && shape.side.style != BorderStyle.none) add(w, shape.side.color);
    }
  }

  _walk(tester, skipFixedColours, (w) {
    switch (w) {
      case DecoratedBox():
        decoration(w, w.decoration);
      case ColoredBox():
        add(w, w.color);
      case Material():
        add(w, w.color);
      case PhysicalModel():
        add(w, w.color);
      case PhysicalShape():
        add(w, w.color);
      case RichText():
        w.text.visitChildren((span) {
          add(w, span.style?.color);
          add(w, span.style?.backgroundColor);
          return true;
        });
        add(w, w.text.style?.color);
    }
  });
  return out;
}

/// Colours on screen that belong only to the [wrong] theme, as "widget colour".
List<String> wrongThemeColours(WidgetTester tester, Brightness wrong) {
  final bad = onlyIn(wrong);
  return {
    for (final (who, c) in screenColours(tester))
      if (bad.contains(c.toARGB32())) '$who 0x${c.toARGB32().toRadixString(16)}',
  }.toList();
}

/// The brightness the app is drawn in right now.
Brightness appBrightness(WidgetTester tester) => Theme.of(tester.element(find.byType(Scaffold).last)).brightness;

/// Every row of every table, for "nothing was lost or duplicated" checks.
Future<Map<String, List<Map<String, Object?>>>> dumpDatabase(AppDatabase db) async => {
      for (final t in db.allTables)
        t.actualTableName: [
          for (final row in await db.customSelect('SELECT * FROM "${t.actualTableName}" ORDER BY rowid').get()) row.data,
        ],
    };

/// The title of sample note n1, read from the database.
Future<String> noteTitle(AppDatabase db) async =>
    (await db.customSelect("SELECT title FROM notes WHERE id = 'n1'").getSingle()).read<String>('title');

/// A language switch relocalizes the sample data in the background: waits
/// until note n1 has [title].
Future<void> waitForSampleTitle(WidgetTester tester, AppDatabase db, String title) async {
  for (var i = 0; i < 50 && await noteTitle(db) != title; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(await noteTitle(db), title);
  await tester.pumpAndSettle();
}

Finder inSettings(Finder f) => find.descendant(of: find.byType(SettingsScreen), matching: f);

/// Opens Settings and taps [label] there (scrolling to it first).
Future<void> tapInSettings(WidgetTester tester, String label) async {
  if (find.byType(SettingsScreen).evaluate().isEmpty) await show(tester, Routes.settings);
  final target = inSettings(find.text(label));
  await tester.scrollUntilVisible(target, 200, scrollable: inSettings(find.byType(Scrollable)).first);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}
