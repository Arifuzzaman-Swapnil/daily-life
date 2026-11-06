import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/dl_format.dart';
import '../../core/format/format_provider.dart';
import '../../core/prefs/app_settings.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';

/// Settings (prototype `settings`, screenshot 80). Build step 1 covers the
/// "Language & region" and "Appearance" sections; profile, notifications,
/// privacy, data management and about follow in later steps.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final s = ref.watch(settingsProvider);
    final ctl = ref.read(settingsProvider.notifier);
    final f = ref.watch(formatProvider);
    final today = ref.watch(clockProvider)();
    final platformDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;

    Widget label(String text) => Text(text, style: DLText.textLabel.copyWith(color: c.textPrimary));
    Widget sample(String text) => Text(text, style: DLText.textBodySm.copyWith(color: c.textSecondary));

    return Scaffold(
      appBar: DLAppBar(
        title: t.settings,
        onLeading: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(Routes.home);
          }
        },
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          DLSectionHeader(t.langRegion, first: true),
          DLCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label(t.language),
                const SizedBox(height: DLSpace.s2),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _LanguageCard(
                          title: 'বাংলা',
                          subtitle: 'Bengali · ডিফল্ট',
                          selected: s.lang == AppLang.bn,
                          onTap: () => ctl.setLanguage(AppLang.bn),
                        ),
                      ),
                      const SizedBox(width: DLSpace.s2),
                      Expanded(
                        child: _LanguageCard(
                          title: 'English',
                          subtitle: 'ইংরেজি',
                          selected: s.lang == AppLang.en,
                          onTap: () => ctl.setLanguage(AppLang.en),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DLSpace.s4),
                label(t.numFormat),
                const SizedBox(height: DLSpace.s2),
                DLSegmentedTabs<DigitStyle>(
                  value: s.digits,
                  options: [(DigitStyle.bn, t.bnDigits), (DigitStyle.en, t.enDigits)],
                  onChanged: ctl.setDigits,
                ),
                const SizedBox(height: DLSpace.s2),
                sample('${f.taka(125000)} · ${f.percent(65)}'),
                const SizedBox(height: DLSpace.s4),
                label(t.dateFmt),
                const SizedBox(height: DLSpace.s2),
                DLSegmentedTabs<DateStyle>(
                  value: s.dateStyle,
                  options: [(DateStyle.written, t.dfLong), (DateStyle.numeric, t.dfNum)],
                  onChanged: ctl.setDateStyle,
                ),
                const SizedBox(height: DLSpace.s2),
                sample('${f.dateMedium(today)} · ${f.time('09:30')}'),
              ],
            ),
          ),
          const SizedBox(height: DLSpace.s3),
          DLList(
            children: [
              DLKeyValueRow(label: t.currency, value: t.bdt),
              DLKeyValueRow(label: t.timezone, value: t.dhaka),
              DLKeyValueRow(label: t.weekStart, value: t.saturday),
              DLListRow(
                minHeight: 56,
                title: t.banglaCal,
                subtitle: f.bangla(today),
                onTap: () => ctl.setBanglaDate(!s.banglaDate),
                trailing: DLSwitch(value: s.banglaDate, onChanged: ctl.setBanglaDate, semanticLabel: t.banglaCal),
              ),
            ],
          ),
          DLSectionHeader(t.appearance),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, mode) in const [ThemeMode.light, ThemeMode.dark, ThemeMode.system].indexed) ...[
                  if (i > 0) const SizedBox(width: DLSpace.s2),
                  Expanded(
                    child: _ThemeCard(
                      mode: mode,
                      label: switch (mode) { ThemeMode.light => t.light, ThemeMode.dark => t.dark, ThemeMode.system => t.system },
                      selected: s.themeMode == mode,
                      onTap: () => ctl.setThemeMode(mode),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (s.themeMode == ThemeMode.system)
            Padding(
              padding: const EdgeInsets.only(top: DLSpace.s2),
              child: sample('${t.themeNote} · ${platformDark ? t.dark : t.light}'),
            ),
        ],
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({required this.title, required this.subtitle, required this.selected, required this.onTap});

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    return DLSelectableCard(
      selected: selected,
      onTap: onTap,
      selectedFill: c.accentSoft,
      padding: const EdgeInsets.all(DLSpace.s3),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 80 - DLSpace.s3 * 2 - 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: DLText.textH3.copyWith(color: c.textPrimary))),
                if (selected)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(color: c.success, shape: BoxShape.circle),
                    child: Icon(DLIcons.check, size: 16, color: c.onSuccess),
                  ),
              ],
            ),
            const SizedBox(height: DLSpace.s1),
            Text(subtitle, style: DLText.textCaption.copyWith(color: c.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// Theme picker card with a miniature of the theme (prototype `.thm` / `.mini`).
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.mode, required this.label, required this.selected, required this.onTap});

  final ThemeMode mode;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    const l = DLColors.light, d = DLColors.dark;
    // Colours of the miniature: [ground, top bar, card, lines] from the real tokens.
    final (ground, bar, card, lines, border) = switch (mode) {
      ThemeMode.light => (l.background, l.brand, l.surface, l.accentSoft, l.divider),
      ThemeMode.dark => (d.background, d.brand, d.surface, d.accentSoft, d.divider),
      ThemeMode.system => (l.background, l.brand, l.surface, l.onBrandAccent, l.borderStrong),
    };
    Widget line(double height, {double widthFactor = 1, required Color color}) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: widthFactor,
          child: Container(height: height, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        );
    return DLSelectableCard(
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.all(DLSpace.s2),
      child: Column(
        children: [
          Container(
            height: 96,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: ground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border),
            ),
            child: Stack(
              children: [
                // "System" shows light on the left half and dark on the right half.
                if (mode == ThemeMode.system)
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerRight,
                      widthFactor: 0.5,
                      child: ColoredBox(color: d.background),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(DLSpace.s2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      line(14, widthFactor: 0.7, color: bar),
                      const SizedBox(height: 5),
                      line(24, color: card),
                      const SizedBox(height: 5),
                      line(8, widthFactor: 0.55, color: lines),
                      const SizedBox(height: 5),
                      line(8, widthFactor: 0.55, color: lines),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DLSpace.s2),
          Text(label, textAlign: TextAlign.center, style: DLText.textLabel.copyWith(color: c.textPrimary)),
        ],
      ),
    );
  }
}
