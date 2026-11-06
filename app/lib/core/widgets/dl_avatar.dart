import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/dl_tokens.dart';
import 'dl_icons.dart';
import 'dl_tone.dart';

/// The person's round avatar (prototype `avStyle`): a soft tone with the
/// name's first letter in the tone's text colour, or the user icon while there
/// is no name yet. [color] picks one of [tones] (the saved avatar colour).
class DLAvatar extends StatelessWidget {
  const DLAvatar({super.key, required this.name, this.size = 52, this.color = 0});

  /// The prototype's four avatar colours, in "Change photo" order.
  static const tones = [DLTone.accent, DLTone.success, DLTone.warning, DLTone.teal];

  final String name;
  final double size;
  final int color;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    final tone = tones[color % tones.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tone.soft(c), shape: BoxShape.circle),
      child: name.isEmpty
          ? Icon(DLIcons.user, size: DLSize.icon, color: tone.text(c))
          : Text(
              name.characters.first.toUpperCase(),
              style: DLText.textH2.copyWith(fontSize: (size * 0.42).roundToDouble(), fontWeight: FontWeight.w700, color: tone.text(c)),
            ),
    );
  }
}

/// The app mark (prototype's inline logo): a navy rounded square with a blue
/// three-quarter ring. It is the app icon, so it keeps its colours in both
/// themes.
class DLLogo extends StatelessWidget {
  const DLLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: size, child: const CustomPaint(painter: _LogoPainter()));
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 48; // drawn on the prototype's 48×48 grid
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(12 * s)),
      Paint()..color = DLColors.light.brand,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(24 * s, 24 * s), radius: 13 * s),
      -math.pi / 2,
      math.pi * 1.5,
      false,
      Paint()
        ..color = DLColors.light.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 * s,
    );
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) => false;
}
