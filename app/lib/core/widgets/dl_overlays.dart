import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/dl_tokens.dart';
import 'dl_buttons.dart';
import 'dl_icons.dart';
import 'dl_motion.dart';
import 'dl_tone.dart';

/// Opens a bottom sheet (prototype `.sheet`) over everything, the bottom nav
/// included: `scrim` behind, `surfaceRaised` with 20px top corners and the sheet
/// shadow, a handle, an optional `textH2` title (and subtitle), padding 8/20/24,
/// at most 86 % of the screen, scrolling, lifted above the keyboard. It slides
/// up over 280 ms (instantly when motion is reduced).
Future<T?> showDLSheet<T>(
  BuildContext context, {
  String? title,
  String? subtitle,
  required WidgetBuilder builder,
}) {
  final reduced = DLMotion.reduced(context);
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    elevation: 0,
    backgroundColor: Colors.transparent,
    barrierColor: context.dl.scrim,
    sheetAnimationStyle: reduced
        ? const AnimationStyle(duration: Duration.zero, reverseDuration: Duration.zero)
        : const AnimationStyle(duration: DLMotion.sheet, reverseDuration: DLMotion.dialog),
    builder: (context) => DLSheet(title: title, subtitle: subtitle, child: builder(context)),
  );
}

/// The sheet surface used by [showDLSheet].
class DLSheet extends StatelessWidget {
  const DLSheet({super.key, required this.child, this.title, this.subtitle});

  final String? title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    final media = MediaQuery.of(context);
    final bottom = math.max(media.viewInsets.bottom, media.viewPadding.bottom);
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: title,
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.86),
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(DLRadius.xl)),
          boxShadow: DLShadows.sheet(Theme.of(context).brightness),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(DLSpace.s5, DLSpace.s2, DLSpace.s5, DLSpace.s6 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: DLSpace.s1, bottom: DLSpace.s3),
                  decoration: BoxDecoration(color: c.borderStrong, borderRadius: const BorderRadius.all(Radius.circular(DLRadius.pill))),
                ),
              ),
              if (title != null)
                Semantics(header: true, child: Text(title!, style: DLText.textH2.copyWith(color: c.textPrimary))),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: DLSpace.s1),
                  child: Text(subtitle!, style: DLText.textBodySm.copyWith(color: c.textSecondary)),
                ),
              if (title != null || subtitle != null) const SizedBox(height: DLSpace.s4),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks to confirm (prototype `.dlg`) and resolves to true only when the user
/// presses the confirm button. Destructive by default: `dangerSoft` trash chip
/// and a `danger` "মুছে ফেলুন" button; `safe: true` uses an info chip and the
/// primary button. Fades and scales in from 96 % over 200 ms.
Future<bool> showDLConfirm(
  BuildContext context, {
  required String title,
  String? body,
  String? confirmLabel,
  bool safe = false,
  IconData? icon,
}) async {
  final reduced = DLMotion.reduced(context);
  final result = await showGeneralDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: AppLocalizations.of(context).cancel,
    barrierColor: context.dl.scrim,
    transitionDuration: reduced ? Duration.zero : DLMotion.dialog,
    pageBuilder: (context, animation, secondaryAnimation) =>
        DLConfirmDialog(title: title, body: body, confirmLabel: confirmLabel, safe: safe, icon: icon),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.ease);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: Tween<double>(begin: 0.96, end: 1).animate(curved), child: child),
      );
    },
  );
  return result ?? false;
}

/// The dialog card shown by [showDLConfirm]: 24 from the sides, its top at 30 %
/// of the screen (moved up if it would not fit), `surfaceRaised`, radius 20.
class DLConfirmDialog extends StatelessWidget {
  const DLConfirmDialog({super.key, required this.title, this.body, this.confirmLabel, this.safe = false, this.icon});

  final String title;
  final String? body;
  final String? confirmLabel;
  final bool safe;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    final t = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    final tone = safe ? DLTone.accent : DLTone.danger;
    final card = Container(
      padding: const EdgeInsets.all(DLSpace.s6),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: const BorderRadius.all(Radius.circular(DLRadius.xl)),
        boxShadow: DLShadows.dialog(Theme.of(context).brightness),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DLIconChip(icon: icon ?? (safe ? DLIcons.info : DLIcons.trash), tone: tone),
            const SizedBox(height: DLSpace.s3),
            Text(title, style: DLText.textH2.copyWith(color: c.textPrimary)),
            if (body != null) ...[
              const SizedBox(height: DLSpace.s3),
              Text(body!, style: DLText.textBody.copyWith(color: c.textSecondary)),
            ],
            const SizedBox(height: DLSpace.s5),
            Row(
              children: [
                Expanded(
                  child: DLButton(
                    label: t.cancel,
                    variant: DLButtonVariant.secondary,
                    size: DLButtonSize.md,
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: DLSpace.s2),
                Expanded(
                  child: DLButton(
                    label: confirmLabel ?? t.del,
                    variant: safe ? DLButtonVariant.primary : DLButtonVariant.danger,
                    size: DLButtonSize.md,
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return DefaultTextStyle(
      style: DLText.textBody.copyWith(color: c.textPrimary),
      child: CustomSingleChildLayout(
        delegate: _DialogLayout(media.padding + EdgeInsets.only(bottom: media.viewInsets.bottom)),
        child: Semantics(scopesRoute: true, namesRoute: true, explicitChildNodes: true, label: title, child: card),
      ),
    );
  }
}

class _DialogLayout extends SingleChildLayoutDelegate {
  const _DialogLayout(this.insets);

  final EdgeInsets insets;
  static const double _side = DLSpace.s6;
  static const double _maxWidth = 480;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final width = math.min(_maxWidth, math.max(0.0, constraints.maxWidth - insets.horizontal - _side * 2));
    final height = math.max(0.0, constraints.maxHeight - insets.vertical - _side * 2);
    return BoxConstraints(minWidth: width, maxWidth: width, maxHeight: height);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final lowest = size.height - insets.bottom - _side - childSize.height;
    final top = math.max(insets.top + _side, math.min(size.height * 0.3, lowest));
    return Offset((size.width - childSize.width) / 2, top);
  }

  @override
  bool shouldRelayout(_DialogLayout oldDelegate) => oldDelegate.insets != insets;
}

/// Short confirmation at the bottom of the screen (prototype `.toast`):
/// `textPrimary` ground with `background` text, radius 12, a 20px icon, 96 above
/// the screen bottom (above the nav bar and the keyboard). Stays 2.4 s; a new
/// toast replaces the one showing. Announced politely to screen readers.
abstract final class DLToast {
  static OverlayEntry? _entry;
  static OverlayState? _overlay;

  /// Shows [message]. `error: true` swaps the green check for a red alert icon.
  static void show(BuildContext context, String message, {bool error = false}) {
    hide();
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ToastView(
        message: message,
        error: error,
        onDone: () {
          if (identical(_entry, entry)) hide();
        },
      ),
    );
    _entry = entry;
    _overlay = overlay;
    overlay.insert(entry);
  }

  /// Removes the toast now, if one is showing.
  static void hide() {
    final entry = _entry;
    final overlay = _overlay;
    _entry = null;
    _overlay = null;
    if (entry != null && overlay != null && overlay.mounted) {
      entry.remove();
      entry.dispose();
    }
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({required this.message, required this.error, required this.onDone});

  final String message;
  final bool error;
  final VoidCallback onDone;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(DLMotion.toastVisible, widget.onDone);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    final media = MediaQuery.of(context);
    final bottom = math.max(96 + media.viewPadding.bottom, media.viewInsets.bottom + DLSpace.s4);
    return Positioned(
      left: DLSpace.s4,
      right: DLSpace.s4,
      bottom: bottom,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: DLMotion.of(context, DLMotion.toast),
        curve: Curves.ease,
        builder: (context, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, 32 * (1 - v)), child: child),
        ),
        child: Semantics(
          liveRegion: true,
          container: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: DLSpace.s4, vertical: DLSpace.s3),
            decoration: BoxDecoration(
              color: c.textPrimary,
              borderRadius: const BorderRadius.all(Radius.circular(DLRadius.md)),
              boxShadow: DLShadows.dropdown(Theme.of(context).brightness),
            ),
            child: DefaultTextStyle(
              style: DLText.textBody.copyWith(color: c.background),
              child: Row(
                children: [
                  Icon(widget.error ? DLIcons.alert : DLIcons.checkCircle, size: 20, color: widget.error ? c.danger : c.success),
                  const SizedBox(width: DLSpace.s3),
                  Expanded(child: Text(widget.message)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
