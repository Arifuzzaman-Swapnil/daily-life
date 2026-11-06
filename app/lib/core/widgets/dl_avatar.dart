import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/dl_tokens.dart';
import 'dl_icons.dart';

/// The person's round avatar (prototype `avStyle`): `accentSoft` with the
/// name's first letter in `accentText`, or the user icon while there is no
/// name yet.
class DLAvatar extends StatelessWidget {
  const DLAvatar({super.key, required this.name, this.size = 52});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
      child: name.isEmpty
          ? Icon(DLIcons.user, size: DLSize.icon, color: c.accentText)
          : Text(
              name.characters.first.toUpperCase(),
              style: DLText.textH2.copyWith(fontWeight: FontWeight.w700, color: c.accentText),
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
