import 'package:flutter/material.dart';

import '../theme/dl_tokens.dart';
import 'dl_icons.dart';
import 'dl_motion.dart';

/// PIN progress (prototype `.pin`): one 16px ring per digit, 16 apart; entered
/// digits are filled with `actionPrimary`.
class DLPinDots extends StatelessWidget {
  const DLPinDots({super.key, required this.filled, this.length = 4});

  final int filled;
  final int length;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    final duration = DLMotion.of(context, DLMotion.fast);
    return Semantics(
      liveRegion: true,
      value: '$filled / $length',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < length; i++) ...[
            if (i > 0) const SizedBox(width: DLSpace.s4),
            AnimatedContainer(
              duration: duration,
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled ? c.actionPrimary : Colors.transparent,
                border: Border.all(color: i < filled ? c.actionPrimary : c.borderStrong, width: 2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Number pad (prototype `.kp`): 1–9, then a blank, 0 and backspace; 56 tall
/// `surfaceSunken` keys, radius 12, 8 apart. [digitLabel] writes a digit in the
/// selected digit style.
class DLKeypad extends StatelessWidget {
  const DLKeypad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    required this.digitLabel,
    required this.deleteLabel,
  });

  final ValueChanged<int> onDigit;
  final VoidCallback onDelete;
  final String Function(int digit) digitLabel;
  final String deleteLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    const radius = BorderRadius.all(Radius.circular(DLRadius.md));
    Widget key({required VoidCallback onTap, required Widget child, String? label}) => DLPressable(
          onTap: onTap,
          borderRadius: radius,
          pressedColor: c.divider,
          semanticLabel: label,
          excludeSemantics: label != null,
          decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: radius),
          child: SizedBox(height: 56, child: Center(child: child)),
        );
    Widget digit(int d) => key(
          onTap: () => onDigit(d),
          child: Text(digitLabel(d), style: DLText.textH2.copyWith(fontSize: 22, color: c.textPrimary)),
        );
    final rows = [
      [for (var d = 1; d <= 3; d++) digit(d)],
      [for (var d = 4; d <= 6; d++) digit(d)],
      [for (var d = 7; d <= 9; d++) digit(d)],
      [
        const SizedBox.shrink(),
        digit(0),
        key(onTap: onDelete, label: deleteLabel, child: Icon(DLIcons.backspace, size: DLSize.icon, color: c.textPrimary)),
      ],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, row) in rows.indexed) ...[
          if (i > 0) const SizedBox(height: DLSpace.s2),
          Row(
            children: [
              for (final (j, cell) in row.indexed) ...[
                if (j > 0) const SizedBox(width: DLSpace.s2),
                Expanded(child: cell),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
