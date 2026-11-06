import 'package:flutter/material.dart';

import '../theme/dl_tokens.dart';
import 'dl_icons.dart';
import 'dl_motion.dart';
import 'dl_tone.dart';

const _cardRadius = BorderRadius.all(Radius.circular(DLRadius.lg));

/// `surface` card with radius 16 and the resting card shadow (prototype `.card`).
/// With [onTap] it is the prototype's `button.card`. `outlined` swaps the
/// shadow for a 1px `divider` border (cards inside a sheet).
class DLCard extends StatelessWidget {
  const DLCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DLSpace.s4),
    this.onTap,
    this.color,
    this.outlined = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Ground override, e.g. `surfaceRaised` for a card that floats.
  final Color? color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: color ?? context.dl.surface,
      borderRadius: _cardRadius,
      border: outlined ? Border.all(color: context.dl.divider) : null,
      boxShadow: outlined ? null : DLShadows.card(Theme.of(context).brightness),
    );
    if (onTap == null) {
      return DecoratedBox(decoration: decoration, child: Padding(padding: padding, child: child));
    }
    return DLPressable(
      onTap: onTap,
      borderRadius: _cardRadius,
      decoration: decoration,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// List group (prototype `.lst`): a card with no padding whose rows are split by
/// `divider` hairlines (`.li + .li { border-top }`). `outlined` swaps the shadow
/// for a 1px `divider` border (lists inside a sheet).
class DLList extends StatelessWidget {
  const DLList({super.key, required this.children, this.outlined = false});

  final List<Widget> children;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    final rule = BoxDecoration(border: Border(top: BorderSide(color: c.divider)));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: _cardRadius,
        border: outlined ? Border.all(color: c.divider) : null,
        boxShadow: outlined ? null : DLShadows.card(Theme.of(context).brightness),
      ),
      child: ClipRRect(
        borderRadius: _cardRadius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, row) in children.indexed)
              i == 0 ? row : DecoratedBox(position: DecorationPosition.foreground, decoration: rule, child: row),
          ],
        ),
      ),
    );
  }
}

/// A row inside [DLList] (prototype `.li`): at least 64 tall, 12/16 padding,
/// optional leading icon chip, title (`textBody`) over subtitle (`textBodySm`,
/// `textSecondary`), optional trailing (amount, chevron, switch). Tappable rows
/// take `surfaceSunken` while pressed.
class DLListRow extends StatelessWidget {
  const DLListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.minHeight = 64,
    this.titleStyle,
    this.subtitleMaxLines = 1,
  });

  final String title;
  final String? subtitle;

  /// Lines the subtitle may wrap to before it is cut with an ellipsis.
  final int subtitleMaxLines;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double minHeight;

  /// Override for the title, e.g. `textBodyLg` for settings rows.
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DLSpace.s4, vertical: DLSpace.s3),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: DLSpace.s3)],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (titleStyle ?? DLText.textBody).copyWith(color: c.textPrimary),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: subtitleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: DLText.textBodySm.copyWith(color: c.textSecondary),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: DLSpace.s3), trailing!],
          ],
        ),
      ),
    );
    if (onTap == null) return Semantics(container: true, child: row);
    return DLPressable(onTap: onTap, pressedColor: c.surfaceSunken, child: row);
  }
}

/// Read-only label / value row (prototype `.kv`), e.g. transaction details.
class DLKeyValueRow extends StatelessWidget {
  const DLKeyValueRow({super.key, required this.label, required this.value, this.valueStyle});

  final String label;
  final String value;

  /// Override for the value, e.g. an amount style.
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DLSpace.s4, vertical: DLSpace.s3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: DLText.textLabel.copyWith(fontWeight: FontWeight.w400, height: 22 / 14, color: c.textSecondary)),
            const SizedBox(width: DLSpace.s4),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: valueStyle ?? DLText.textBody.copyWith(height: 22 / 15, color: c.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card with a 2px border that turns `accent` when selected (prototype `.lng`,
/// `.thm`, `.tool.on`). [selectedFill] tints the selected card, e.g. `accentSoft`.
class DLSelectableCard extends StatelessWidget {
  const DLSelectableCard({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.padding = const EdgeInsets.all(DLSpace.s4),
    this.selectedFill,
  });

  final bool selected;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? selectedFill;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    return DLPressable(
      onTap: onTap,
      selected: selected,
      borderRadius: _cardRadius,
      decoration: BoxDecoration(
        color: selected ? (selectedFill ?? c.surface) : c.surface,
        borderRadius: _cardRadius,
        border: Border.all(color: selected ? c.accent : c.divider, width: 2),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Small grey label above a group of rows (prototype `.dh`), e.g. a date
/// heading in a transaction list or a settings section.
class DLSectionHeader extends StatelessWidget {
  const DLSectionHeader(this.text, {super.key, this.first = false});

  final String text;

  /// The first header on a screen sits closer to the top.
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(DLSpace.s1, first ? DLSpace.s4 : DLSpace.s6, DLSpace.s1, DLSpace.s2),
      child: Semantics(
        header: true,
        child: Text(text, style: DLText.textBodySm.copyWith(fontWeight: FontWeight.w600, color: context.dl.textSecondary)),
      ),
    );
  }
}

/// Section title with an optional trailing link or control (prototype `.sec`):
/// `textH3`, 24 above, 12 to its content.
class DLSectionTitle extends StatelessWidget {
  const DLSectionTitle(this.title, {super.key, this.trailing, this.first = false});

  final String title;
  final Widget? trailing;

  /// Drop the 24 top margin (first section on a screen).
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : DLSpace.s6, bottom: DLSpace.s3),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: DLText.textH3.copyWith(color: context.dl.textPrimary)),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: DLSpace.s2), trailing!],
        ],
      ),
    );
  }
}

/// Tinted note (prototype `.card.row` with a soft ground): a 20px icon beside
/// `textBodySm` words in the tone's text colour, e.g. the allocation and
/// shop-credit explanations.
class DLNote extends StatelessWidget {
  const DLNote(this.text, {super.key, this.tone = DLTone.accent, this.icon = DLIcons.info});

  final String text;
  final DLTone tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    final fg = tone.text(c);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DLSpace.s4),
      decoration: BoxDecoration(color: tone.soft(c), borderRadius: _cardRadius),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 20, color: fg)),
          const SizedBox(width: DLSpace.s3),
          Expanded(child: Text(text, style: DLText.textBodySm.copyWith(color: fg))),
        ],
      ),
    );
  }
}
