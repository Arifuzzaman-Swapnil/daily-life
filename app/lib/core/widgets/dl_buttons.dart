import 'package:flutter/material.dart';

import '../theme/dl_tokens.dart';
import 'dl_chip.dart';
import 'dl_icons.dart';
import 'dl_motion.dart';

/// Button heights: lg 52 (forms, full width), md 44 (dialogs, empty states), sm 36 (inside cards).
enum DLButtonSize { lg, md, sm }

/// `.bp` primary, `.bsec` secondary (outlined), `.bt` tonal, `.bd` danger.
enum DLButtonVariant { primary, secondary, tonal, danger }

/// Text button (prototype `.btn`). lg and md fill the width they are given
/// (wrap in `Expanded` inside a row); sm and `expand: false` hug their label.
class DLButton extends StatelessWidget {
  const DLButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = DLButtonVariant.primary,
    this.size = DLButtonSize.lg,
    this.expand,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final DLButtonVariant variant;
  final DLButtonSize size;

  /// Defaults to true for lg/md, false for sm.
  final bool? expand;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    final enabled = onPressed != null;
    final (Color bg, Color fg, Color? border, Color? pressed) = !enabled
        ? (c.surfaceSunken, c.textDisabled, null, null)
        : switch (variant) {
            DLButtonVariant.primary => (c.actionPrimary, c.onActionPrimary, null, c.actionPrimaryHover),
            DLButtonVariant.secondary => (c.surface, c.accentText, c.borderStrong, c.accentSoft),
            DLButtonVariant.tonal => (c.accentSoft, c.accentText, null, null),
            DLButtonVariant.danger => (c.danger, c.onDanger, null, null),
          };
    final (height, hPad, radius) = switch (size) {
      DLButtonSize.lg => (DLSize.controlLg, DLSpace.s6, DLRadius.md),
      DLButtonSize.md => (DLSize.controlMd, DLSpace.s5, DLRadius.md),
      DLButtonSize.sm => (DLSize.controlSm, 14.0, DLRadius.sm),
    };
    final small = size == DLButtonSize.sm;
    final style = (small ? DLText.textButton.copyWith(fontSize: 14) : DLText.textButton).copyWith(color: fg);
    final shape = BorderRadius.circular(radius);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: small ? 16 : 20, color: fg),
          const SizedBox(width: DLSpace.s2),
        ],
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: style),
        ),
      ],
    );
    final button = DLPressable(
      onTap: onPressed,
      borderRadius: shape,
      pressedColor: pressed,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: shape,
        border: border == null ? null : Border.all(color: border),
      ),
      child: SizedBox(
        // The 1px outline sits inside the height, like the prototype's border-box.
        height: border == null ? height : height - 2,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: Center(widthFactor: 1, child: content),
        ),
      ),
    );
    return (expand ?? !small) ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Round icon-only button (prototype `.ib`): 48 touch target, `textPrimary` icon,
/// `surfaceSunken` when pressed. `tonal` is `.ib.tn`: 44, `accentSoft` with an
/// `accentText` icon. The [tooltip] is also its accessible label.
class DLIconButton extends StatelessWidget {
  const DLIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.tonal = false,
    this.color,
    this.size,
    this.iconSize = DLSize.icon,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool tonal;

  /// Icon colour override, e.g. `onBrand` on the navy hero.
  final Color? color;

  /// Defaults to 48 (44 when tonal).
  final double? size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    const shape = BorderRadius.all(Radius.circular(DLRadius.pill));
    final fg = onPressed == null ? c.textDisabled : (color ?? (tonal ? c.accentText : c.textPrimary));
    final dimension = size ?? (tonal ? DLSize.controlMd : DLSize.touch);
    return Tooltip(
      message: tooltip,
      // The button itself carries the label, so screen readers read one node.
      excludeFromSemantics: true,
      child: DLPressable(
        onTap: onPressed,
        semanticLabel: tooltip,
        borderRadius: shape,
        pressedColor: tonal ? null : c.surfaceSunken,
        decoration: tonal ? BoxDecoration(color: c.accentSoft, borderRadius: shape) : null,
        child: SizedBox.square(
          dimension: dimension,
          child: Center(child: Icon(icon, size: iconSize, color: fg)),
        ),
      ),
    );
  }
}

/// Blue text link (prototype `.lnk`), e.g. "সব দেখুন ›" beside a section title.
class DLLinkButton extends StatelessWidget {
  const DLLinkButton({super.key, required this.label, required this.onPressed, this.chevron = true});

  final String label;
  final VoidCallback? onPressed;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    final fg = onPressed == null ? c.textDisabled : c.accentText;
    return DLPressable(
      onTap: onPressed,
      borderRadius: const BorderRadius.all(Radius.circular(DLRadius.sm)),
      pressedColor: c.accentSoft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: DLSize.controlMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DLSpace.s1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: DLText.textLabel.copyWith(color: fg)),
              if (chevron) ...[
                const SizedBox(width: 2),
                Icon(DLIcons.chevronRight, size: 16, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating action button (prototype `.fab`): 56, radius 16, `accent` fill,
/// `onAccent` icon, the FAB shadow. Place it 16 from the right and 16 above the
/// bottom nav (or the screen bottom).
class DLFab extends StatelessWidget {
  const DLFab({super.key, required this.tooltip, required this.onPressed, this.icon = DLIcons.plus});

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    const shape = BorderRadius.all(Radius.circular(DLRadius.lg));
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: DLPressable(
        onTap: onPressed,
        semanticLabel: tooltip,
        borderRadius: shape,
        decoration: BoxDecoration(
          color: c.accent,
          borderRadius: shape,
          boxShadow: DLShadows.fab(Theme.of(context).brightness),
        ),
        child: SizedBox.square(
          dimension: DLSize.fab,
          child: Center(child: Icon(icon, size: DLSize.icon, color: c.onAccent)),
        ),
      ),
    );
  }
}

/// Dashed "add another" button (prototype `.btn.bt` with a dashed `borderStrong`
/// outline): full width, 52 tall, `accentSoft` ground, `accentText` plus icon and
/// label. Adds a budget row, a savings goal.
class DLAddButton extends StatelessWidget {
  const DLAddButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: DLDashedBorderPainter(
        color: context.dl.borderStrong,
        borderRadius: const BorderRadius.all(Radius.circular(DLRadius.md)),
      ),
      child: DLButton(label: label, icon: DLIcons.plus, onPressed: onPressed, variant: DLButtonVariant.tonal),
    );
  }
}
