import 'package:flutter/material.dart';

import '../theme/dl_tokens.dart';

/// Motion timings from the design system: 150 ms for colour and press,
/// 300 ms for progress, sheets slide up, dialogs fade and scale from 96 %.
abstract final class DLMotion {
  /// Colour changes and the press scale.
  static const fast = Duration(milliseconds: 150);

  /// Theme cross-fade of grounds and surfaces.
  static const theme = Duration(milliseconds: 250);

  /// Progress bars and chart bars.
  static const progress = Duration(milliseconds: 300);

  /// Progress rings.
  static const ring = Duration(milliseconds: 400);

  /// Dialog fade + scale.
  static const dialog = Duration(milliseconds: 200);

  /// Bottom sheet slide-up.
  static const sheet = Duration(milliseconds: 280);

  /// Toast slide-up.
  static const toast = Duration(milliseconds: 220);

  /// How long a toast stays on screen.
  static const toastVisible = Duration(milliseconds: 2400);

  /// Whether the user asked the system to reduce motion.
  static bool reduced(BuildContext context) => MediaQuery.disableAnimationsOf(context);

  /// [duration], or zero when the user asked the system to reduce motion.
  static Duration of(BuildContext context, Duration duration) => reduced(context) ? Duration.zero : duration;
}

/// Press feedback shared by every tappable DL component:
/// - the prototype's `button:active { transform: scale(.97) }`,
/// - an optional pressed fill (rows take `surfaceSunken`, primary takes `actionPrimaryHover`),
/// - a 2px `focusRing` outline with a 2px offset while focused from a keyboard.
///
/// [decoration] is painted inside the scale and under the pressed fill, so a
/// component's own ground scales with it.
class DLPressable extends StatefulWidget {
  const DLPressable({
    super.key,
    required this.onTap,
    required this.child,
    this.onLongPress,
    this.decoration,
    this.borderRadius = BorderRadius.zero,
    this.pressedColor,
    this.scaleOnPress = true,
    this.selected,
    this.toggled,
    this.semanticLabel,
    this.excludeSemantics = false,
  });

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BoxDecoration? decoration;
  final BorderRadius borderRadius;
  final Color? pressedColor;
  final bool scaleOnPress;

  /// Semantics: selected state (chips, segments, selectable cards).
  final bool? selected;

  /// Semantics: on/off state (switches, checkboxes).
  final bool? toggled;
  final String? semanticLabel;

  /// Replace the child's semantics with [semanticLabel].
  final bool excludeSemantics;
  final Widget child;

  @override
  State<DLPressable> createState() => _DLPressableState();
}

class _DLPressableState extends State<DLPressable> {
  bool _pressed = false;
  bool _focused = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  void _setFocused(bool value) {
    if (_focused != value) setState(() => _focused = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    final enabled = widget.onTap != null || widget.onLongPress != null;
    final ring = _focused && FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    final pressed = widget.pressedColor ?? Colors.transparent;
    Widget body = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        borderRadius: widget.borderRadius,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.pressed) ? pressed : Colors.transparent),
        onHighlightChanged: _setPressed,
        onFocusChange: _setFocused,
        child: widget.child,
      ),
    );
    if (widget.decoration != null) {
      body = AnimatedContainer(
        duration: DLMotion.of(context, DLMotion.fast),
        decoration: widget.decoration,
        child: body,
      );
    }
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      selected: widget.selected,
      toggled: widget.toggled,
      label: widget.semanticLabel,
      excludeSemantics: widget.excludeSemantics,
      child: AnimatedScale(
        scale: _pressed && widget.scaleOnPress && enabled ? 0.97 : 1,
        duration: DLMotion.of(context, DLMotion.fast),
        curve: Curves.ease,
        child: CustomPaint(
          foregroundPainter: ring ? DLFocusRingPainter(color: c.focusRing, borderRadius: widget.borderRadius) : null,
          child: body,
        ),
      ),
    );
  }
}

/// The 2px focus outline, drawn 2px outside the element's rounded bounds.
class DLFocusRingPainter extends CustomPainter {
  const DLFocusRingPainter({required this.color, required this.borderRadius});

  final Color color;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    // Offset 2 + half the 2px stroke.
    final rrect = borderRadius.toRRect(Offset.zero & size).inflate(3);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(DLFocusRingPainter oldDelegate) => oldDelegate.color != color || oldDelegate.borderRadius != borderRadius;
}
