import 'package:dailylife/core/theme/dl_theme.dart';
import 'package:dailylife/core/theme/dl_tokens.dart';
import 'package:dailylife/core/widgets/dl_motion.dart';
import 'package:dailylife/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bengali strings, for tooltips and button labels.
final bn = lookupAppLocalizations(const Locale('bn'));

/// Pumps [child] in a DL-themed app on a phone (393×852 by default), inside a
/// scrolling page with the 16px gutter unless `scroll: false`.
Future<void> pumpDL(
  WidgetTester tester,
  Widget child, {
  bool dark = false,
  String lang = 'bn',
  double width = 393,
  double height = 852,
  bool scroll = true,
  bool reduceMotion = false,
  bool settle = true,
}) async {
  tester.view.physicalSize = Size(width * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: DLTheme.light(),
      darkTheme: DLTheme.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(lang),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: app!,
      ),
      home: Scaffold(
        body: scroll ? ListView(padding: const EdgeInsets.all(16), children: [child]) : child,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// The DL colours in effect.
DLColors colorsOf(WidgetTester tester) => tester.element(find.byType(Scaffold).first).dl;

/// Decoration of the first `AnimatedContainer` under [of] (DL components keep
/// their ground in one so colour changes animate).
BoxDecoration groundOf(WidgetTester tester, Finder of) =>
    tester.widget<AnimatedContainer>(find.descendant(of: of, matching: find.byType(AnimatedContainer)).first).decoration! as BoxDecoration;

/// The semantics a DL component declares: the `Semantics` its [DLPressable]
/// builds. [of] is the component or anything inside it.
SemanticsProperties semanticsOf(WidgetTester tester, Finder of) {
  final own = find.descendant(of: of, matching: find.byType(DLPressable), matchRoot: true);
  final pressable = own.evaluate().isNotEmpty ? own.first : find.ancestor(of: of, matching: find.byType(DLPressable)).first;
  return tester.widget<Semantics>(find.descendant(of: pressable, matching: find.byType(Semantics)).first).properties;
}

/// Style of the [Text] showing [text].
TextStyle styleOf(WidgetTester tester, String text) => tester.widget<Text>(find.text(text)).style!;
