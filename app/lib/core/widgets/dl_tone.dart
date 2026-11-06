import 'package:flutter/material.dart';

import '../theme/dl_tokens.dart';

/// The status tones of the prototype's `t-ac / t-su / t-wa / t-da / t-ct / t-nu`
/// classes: a soft fill with words and icons in the matching `*-text` colour,
/// plus a solid colour for marks (bars, dots).
enum DLTone {
  accent,
  success,
  warning,
  danger,
  teal,
  neutral;

  /// Soft fill behind words and icons.
  Color soft(DLColors c) => switch (this) {
        DLTone.accent => c.accentSoft,
        DLTone.success => c.successSoft,
        DLTone.warning => c.warningSoft,
        DLTone.danger => c.dangerSoft,
        DLTone.teal => c.catTaskSoft,
        DLTone.neutral => c.surfaceSunken,
      };

  /// Words and icons on [soft].
  Color text(DLColors c) => switch (this) {
        DLTone.accent => c.accentText,
        DLTone.success => c.successText,
        DLTone.warning => c.warningText,
        DLTone.danger => c.dangerText,
        DLTone.teal => c.catTaskText,
        DLTone.neutral => c.textPrimary,
      };

  /// Solid fill for marks: progress bars (`.bar.su` …), dots.
  Color solid(DLColors c) => switch (this) {
        DLTone.accent => c.accent,
        DLTone.success => c.success,
        DLTone.warning => c.warning,
        DLTone.danger => c.danger,
        DLTone.teal => c.catTask,
        DLTone.neutral => c.borderStrong,
      };
}

/// Square tinted icon chip (prototype `.ic`): 44 with radius 12 and a 24 icon,
/// `.ic.s36` 36 with radius 10 and a 20 icon, quick actions 52 with radius 16.
class DLIconChip extends StatelessWidget {
  const DLIconChip({super.key, required this.icon, this.tone = DLTone.neutral, this.size = 44});

  final IconData icon;
  final DLTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    final radius = size >= 52
        ? DLRadius.lg
        : size >= 44
            ? DLRadius.md
            : 10.0; // prototype `.ic.s36`
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tone.soft(c), borderRadius: BorderRadius.circular(radius)),
      child: Icon(icon, size: size >= 44 ? DLSize.icon : 20, color: tone.text(c)),
    );
  }
}
