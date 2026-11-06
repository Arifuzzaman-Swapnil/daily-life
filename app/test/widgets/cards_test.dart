import 'package:dailylife/core/theme/dl_tokens.dart';
import 'package:dailylife/core/widgets/dl_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  testWidgets('DLCard: surface, radius 16, card shadow, 16 padding, optional tap', (tester) async {
    var taps = 0;
    await pumpDL(
      tester,
      Column(
        children: [
          const DLCard(child: Text('স্থির')),
          const SizedBox(height: 12),
          DLCard(onTap: () => taps++, child: const Text('চাপা যায়')),
        ],
      ),
    );
    final c = colorsOf(tester);
    final box = tester.widget<DecoratedBox>(find.ancestor(of: find.text('স্থির'), matching: find.byType(DecoratedBox)).first);
    final deco = box.decoration as BoxDecoration;
    expect(deco.color, c.surface);
    expect(deco.borderRadius, const BorderRadius.all(Radius.circular(DLRadius.lg)));
    expect(deco.boxShadow, DLShadows.card(Brightness.light));
    expect(tester.getTopLeft(find.text('স্থির')) - tester.getTopLeft(find.byType(DLCard).first), const Offset(16, 16));
    expect(groundOf(tester, find.byType(DLCard).last).color, c.surface);
    await tester.tap(find.text('চাপা যায়'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('DLList splits rows with hairlines; DLListRow is ≥64 tall with title, subtitle, trailing', (tester) async {
    String? opened;
    await pumpDL(
      tester,
      DLList(
        children: [
          DLListRow(
            leading: const DLIconChip(icon: DLIcons.wallet, tone: DLTone.success),
            title: 'বেতন',
            subtitle: 'বেতন · আজ',
            trailing: const Text('+৳৫০,০০০'),
            onTap: () => opened = 'salary',
          ),
          const DLListRow(title: 'দুপুরের খাবার', subtitle: 'খাবার · আজ'),
          const DLKeyValueRow(label: 'পেমেন্ট পদ্ধতি', value: 'নগদ টাকা'),
        ],
      ),
    );
    final c = colorsOf(tester);
    final rules = find.descendant(
      of: find.byType(DLList),
      matching: find.byWidgetPredicate((w) => w is DecoratedBox && w.position == DecorationPosition.foreground),
    );
    expect(rules, findsNWidgets(2), reason: 'one hairline between each pair of rows, none above the first');
    expect(((tester.widget<DecoratedBox>(rules.first).decoration as BoxDecoration).border! as Border).top.color, c.divider);

    expect(tester.getSize(find.byType(DLListRow).first).height, greaterThanOrEqualTo(64));
    expect(styleOf(tester, 'বেতন · আজ').color, c.textSecondary);
    expect(find.text('+৳৫০,০০০'), findsOneWidget);
    expect(find.text('নগদ টাকা'), findsOneWidget);
    expect(styleOf(tester, 'পেমেন্ট পদ্ধতি').color, c.textSecondary);

    final chip = tester.widget<Container>(find.descendant(of: find.byType(DLIconChip), matching: find.byType(Container)));
    expect((chip.decoration! as BoxDecoration).color, c.successSoft);
    expect(tester.widget<Icon>(find.byIcon(DLIcons.wallet)).color, c.successText);
    expect(tester.getSize(find.byType(DLIconChip)), const Size.square(44));

    await tester.tap(find.text('বেতন'));
    await tester.pump();
    expect(opened, 'salary');
  });

  testWidgets('DLSelectableCard: accent border when selected, divider otherwise; reports selection', (tester) async {
    final semantics = tester.ensureSemantics();
    var picked = 'bn';
    await pumpDL(
      tester,
      StatefulBuilder(
        builder: (context, setState) => Row(
          children: [
            for (final lang in ['bn', 'en'])
              Expanded(
                child: DLSelectableCard(
                  selected: picked == lang,
                  selectedFill: context.dl.accentSoft,
                  onTap: () => setState(() => picked = lang),
                  child: Text(lang),
                ),
              ),
          ],
        ),
      ),
    );
    final c = colorsOf(tester);
    BoxDecoration card(String lang) => groundOf(tester, find.widgetWithText(DLSelectableCard, lang));
    expect((card('bn').border! as Border).top, BorderSide(color: c.accent, width: 2));
    expect(card('bn').color, c.accentSoft);
    expect((card('en').border! as Border).top, BorderSide(color: c.divider, width: 2));
    expect(tester.getSemantics(find.byType(DLSelectableCard).first), containsSemantics(isButton: true, isSelected: true));

    await tester.tap(find.text('en'));
    await tester.pumpAndSettle();
    expect(picked, 'en');
    expect((card('en').border! as Border).top.color, c.accent);
    semantics.dispose();
  });

  testWidgets('section headers are headings with the prototype styles', (tester) async {
    await pumpDL(
      tester,
      Column(
        children: [
          const DLSectionHeader('আজ', first: true),
          DLSectionTitle('সাম্প্রতিক লেনদেন', trailing: DLLinkButton(label: 'সব দেখুন', onPressed: () {})),
        ],
      ),
    );
    final c = colorsOf(tester);
    expect(styleOf(tester, 'আজ').fontSize, 13);
    expect(styleOf(tester, 'আজ').color, c.textSecondary);
    expect(styleOf(tester, 'সাম্প্রতিক লেনদেন').fontSize, DLText.textH3.fontSize);
    expect(find.text('সব দেখুন'), findsOneWidget);
  });

  testWidgets('DLBalanceHero: navy ground, hero amount, two stat panels, month pill', (tester) async {
    var month = false;
    var income = false;
    await pumpDL(
      tester,
      DLBalanceHero(
        label: 'হাতে আছে',
        amount: '৳১৭,১২০',
        hint: 'আয় − খরচ − সঞ্চয়ে জমা',
        trailing: DLHeroPill(label: 'নভেম্বর ২০২৬', onTap: () => month = true),
        stats: [
          DLHeroStat(icon: DLIcons.wallet, label: 'মোট আয়', amount: '৳৫০,০০০', onTap: () => income = true),
          const DLHeroStat(icon: DLIcons.wallet, label: 'মোট খরচ', amount: '৳২২,৮৮০'),
        ],
      ),
    );
    final c = colorsOf(tester);
    final hero = tester.widget<DecoratedBox>(find.descendant(of: find.byType(DLHero), matching: find.byType(DecoratedBox)).first);
    expect((hero.decoration as BoxDecoration).color, c.brand);
    expect((hero.decoration as BoxDecoration).borderRadius, const BorderRadius.all(Radius.circular(DLRadius.xl)));
    expect(styleOf(tester, '৳১৭,১২০').fontSize, DLText.amountHero.fontSize);
    expect(styleOf(tester, '৳১৭,১২০').color, c.onBrand);
    expect(styleOf(tester, 'হাতে আছে').color, c.brandMuted);
    expect(find.byType(DLHeroTile), findsNWidgets(2));
    expect(groundOf(tester, find.byType(DLHeroPill)).color, c.brandHover);

    await tester.tap(find.text('নভেম্বর ২০২৬'));
    await tester.tap(find.text('৳৫০,০০০'));
    await tester.pump();
    expect(month, isTrue);
    expect(income, isTrue);
  });

  testWidgets('DLEmptyState: halo, title, body and action; in a card when asked', (tester) async {
    var added = false;
    await pumpDL(
      tester,
      DLEmptyState(
        icon: DLIcons.wallet,
        title: 'এখনো কোনো লেনদেন নেই',
        body: 'প্রথম আয় বা খরচ যোগ করুন।',
        actionLabel: 'আয় যোগ করুন',
        onAction: () => added = true,
        inCard: true,
      ),
    );
    final c = colorsOf(tester);
    expect(find.byType(DLCard), findsOneWidget);
    expect(tester.widget<Icon>(find.byIcon(DLIcons.wallet)).color, c.accentText);
    expect(styleOf(tester, 'এখনো কোনো লেনদেন নেই').fontSize, DLText.textH3.fontSize);
    expect(styleOf(tester, 'প্রথম আয় বা খরচ যোগ করুন।').color, c.textSecondary);
    expect(tester.getSize(find.byType(DLButton)).height, DLSize.controlMd);
    await tester.tap(find.text('আয় যোগ করুন'));
    await tester.pump();
    expect(added, isTrue);
  });
}
