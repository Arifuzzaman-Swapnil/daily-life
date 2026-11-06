// The language and theme pickers shared by onboarding (screens 02, 04) and
// Settings (screen 80): prototype `.lng` and `.thm` / `.mini`.
import 'package:flutter/material.dart';

import '../../core/format/dl_format.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';

/// The two language cards. Onboarding stacks them [large] (`.lng`: 96 tall,
/// 22px names); Settings puts them side by side (80 tall, 18px names).
class LanguageCards extends StatelessWidget {
  const LanguageCards({super.key, required this.value, required this.onChanged, this.large = false});

  final AppLang value;
  final ValueChanged<AppLang> onChanged;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final (lang, title, subtitle) in const [
        (AppLang.bn, 'বাংলা', 'Bengali · ডিফল্ট'),
        (AppLang.en, 'English', 'ইংরেজি'),
      ])
        LanguageCard(title: title, subtitle: subtitle, selected: value == lang, large: large, onTap: () => onChanged(lang)),
    ];
    if (large) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [cards[0], const SizedBox(height: DLSpace.s3), cards[1]]);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Expanded(child: cards[0]), const SizedBox(width: DLSpace.s2), Expanded(child: cards[1])],
      ),
    );
  }
}

class LanguageCard extends StatelessWidget {
  const LanguageCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.large = false,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    final pad = large ? DLSpace.s4 : DLSpace.s3;
    return DLSelectableCard(
      selected: selected,
      onTap: onTap,
      selectedFill: c.accentSoft,
      padding: EdgeInsets.all(pad),
      child: ConstrainedBox(
        // The card's 2px border sits inside the prototype's min-height.
        constraints: BoxConstraints(minHeight: (large ? 96 : 80) - pad * 2 - 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: (large ? DLText.textH2 : DLText.textH3).copyWith(color: c.textPrimary))),
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
            Text(subtitle, style: (large ? DLText.textBodySm : DLText.textCaption).copyWith(color: c.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// Light, Dark and System side by side, each with a miniature of the theme.
class ThemeCards extends StatelessWidget {
  const ThemeCards({super.key, required this.value, required this.onChanged});

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, mode) in const [ThemeMode.light, ThemeMode.dark, ThemeMode.system].indexed) ...[
            if (i > 0) const SizedBox(width: DLSpace.s2),
            Expanded(
              child: ThemeCard(
                mode: mode,
                label: switch (mode) { ThemeMode.light => t.light, ThemeMode.dark => t.dark, ThemeMode.system => t.system },
                selected: value == mode,
                onTap: () => onChanged(mode),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Theme picker card with a miniature of the theme (prototype `.thm` / `.mini`).
class ThemeCard extends StatelessWidget {
  const ThemeCard({super.key, required this.mode, required this.label, required this.selected, required this.onTap});

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
