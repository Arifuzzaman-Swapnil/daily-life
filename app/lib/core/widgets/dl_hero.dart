import 'package:flutter/material.dart';

import '../theme/dl_tokens.dart';
import 'dl_icons.dart';
import 'dl_motion.dart';

const _heroRadius = BorderRadius.all(Radius.circular(DLRadius.xl));
const _tileRadius = BorderRadius.all(Radius.circular(DLRadius.md));

/// The one navy block on a screen (prototype `.hero`): `brand` ground, radius
/// 20, padding 20, `onBrand` text. Use `brandMuted` for secondary words and
/// [DLHeroTile] for the raised `brandHover` panels inside it.
class DLHero extends StatelessWidget {
  const DLHero({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(DLSpace.s5)});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    final content = DefaultTextStyle.merge(
      style: TextStyle(color: c.onBrand),
      child: IconTheme.merge(data: IconThemeData(color: c.onBrand), child: Padding(padding: padding, child: child)),
    );
    final decoration = BoxDecoration(color: c.brand, borderRadius: _heroRadius);
    if (onTap == null) return DecoratedBox(decoration: decoration, child: content);
    return DLPressable(onTap: onTap, borderRadius: _heroRadius, decoration: decoration, child: content);
  }
}

/// Raised panel inside [DLHero] (prototype `.hero .pl`): `brandHover`, radius 12, padding 12.
class DLHeroTile extends StatelessWidget {
  const DLHeroTile({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(color: context.dl.brandHover, borderRadius: _tileRadius);
    final content = Padding(padding: const EdgeInsets.all(DLSpace.s3), child: child);
    if (onTap == null) return DecoratedBox(decoration: decoration, child: content);
    return DLPressable(onTap: onTap, borderRadius: _tileRadius, decoration: decoration, child: content);
  }
}

/// Pill button on the hero (the month picker "নভেম্বর ২০২৬ ⌄"): `brandHover`, 36 tall.
class DLHeroPill extends StatelessWidget {
  const DLHeroPill({super.key, required this.label, required this.onTap, this.semanticLabel});

  final String label;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    const shape = BorderRadius.all(Radius.circular(DLRadius.pill));
    return DLPressable(
      onTap: onTap,
      borderRadius: shape,
      semanticLabel: semanticLabel,
      decoration: BoxDecoration(color: c.brandHover, borderRadius: shape),
      child: SizedBox(
        height: DLSize.controlSm,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DLSpace.s3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: DLText.textLabel.copyWith(color: c.onBrand)),
              const SizedBox(width: DLSpace.s1),
              Icon(DLIcons.chevronDown, size: 16, color: c.onBrand),
            ],
          ),
        ),
      ),
    );
  }
}

/// One income/expense panel of [DLBalanceHero].
class DLHeroStat {
  const DLHeroStat({required this.icon, required this.label, required this.amount, this.onTap});

  final IconData icon;
  final String label;

  /// Already formatted, e.g. `৳৫০,০০০`.
  final String amount;
  final VoidCallback? onTap;
}

/// Balance card (Home "হাতে আছে", Finance "অবশিষ্ট"): label with an optional
/// trailing control, the `amountHero` figure, an optional hint, and a 2-column
/// row of [DLHeroStat] panels.
class DLBalanceHero extends StatelessWidget {
  const DLBalanceHero({
    super.key,
    required this.label,
    required this.amount,
    this.hint,
    this.trailing,
    this.stats = const [],
    this.onAmountTap,
  });

  final String label;

  /// Already formatted (or masked) amount.
  final String amount;
  final String? hint;

  /// E.g. a [DLHeroPill] month picker.
  final Widget? trailing;
  final List<DLHeroStat> stats;
  final VoidCallback? onAmountTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    Widget figure = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(amount, style: DLText.amountHero.copyWith(color: c.onBrand)),
        if (hint != null) Text(hint!, style: DLText.textBodySm.copyWith(color: c.brandMuted)),
      ],
    );
    if (onAmountTap != null) {
      figure = DLPressable(
        onTap: onAmountTap,
        borderRadius: const BorderRadius.all(Radius.circular(DLRadius.sm)),
        child: SizedBox(width: double.infinity, child: figure),
      );
    }
    return DLHero(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: DLText.textLabel.copyWith(color: c.brandMuted))),
              ?trailing,
            ],
          ),
          SizedBox(height: trailing != null ? DLSpace.s2 : DLSpace.s1),
          figure,
          if (stats.isNotEmpty) ...[
            const SizedBox(height: DLSpace.s4),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, s) in stats.indexed) ...[
                    if (i > 0) const SizedBox(width: DLSpace.s3),
                    Expanded(
                      child: DLHeroTile(
                        onTap: s.onTap,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(s.icon, size: 16, color: c.onBrandAccent),
                                const SizedBox(width: DLSpace.s1),
                                Flexible(
                                  child: Text(
                                    s.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: DLText.textCaption.copyWith(color: c.brandMuted),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: DLSpace.s1),
                            Text(s.amount, style: DLText.amountMd.copyWith(color: c.onBrand)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
