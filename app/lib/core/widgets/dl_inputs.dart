import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../theme/dl_tokens.dart';
import 'dl_buttons.dart';
import 'dl_icons.dart';
import 'dl_motion.dart';

const _controlRadius = BorderRadius.all(Radius.circular(DLRadius.md));

/// Field error line (prototype `.ert`): 16px alert icon + `dangerText` 13px.
class DLErrorText extends StatelessWidget {
  const DLErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(DLIcons.alert, size: 16, color: c.dangerText),
          ),
          const SizedBox(width: DLSpace.s1),
          Expanded(child: Text(message, style: DLText.textBodySm.copyWith(color: c.dangerText))),
        ],
      ),
    );
  }
}

/// Form field frame (prototype `.fld`): label (`textLabel`) with an optional
/// "(ঐচ্ছিক)" suffix in `textSecondary`, the control, then the error line and/or
/// helper text, 8 apart, 16 below. Wraps any control: text fields, selects,
/// chip groups.
class DLField extends StatelessWidget {
  const DLField({
    super.key,
    required this.child,
    this.label,
    this.optionalLabel,
    this.error,
    this.helper,
    this.bottomGap = DLSpace.s4,
  });

  final String? label;

  /// The localized word "optional", shown as "(…)" after the label.
  final String? optionalLabel;
  final String? error;
  final String? helper;
  final double bottomGap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null) ...[
            Text.rich(
              TextSpan(
                text: label,
                children: [
                  if (optionalLabel != null) TextSpan(text: ' ($optionalLabel)', style: TextStyle(color: c.textSecondary)),
                ],
              ),
              style: DLText.textLabel.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: DLSpace.s2),
          ],
          child,
          if (error != null) ...[const SizedBox(height: DLSpace.s2), DLErrorText(error!)],
          if (helper != null) ...[
            const SizedBox(height: DLSpace.s2),
            Text(helper!, style: DLText.textBodySm.copyWith(color: c.textSecondary)),
          ],
        ],
      ),
    );
  }
}

OutlineInputBorder _border(Color color, double width) =>
    OutlineInputBorder(borderRadius: _controlRadius, borderSide: BorderSide(color: color, width: width));

/// Text input (prototype `.inp`) inside a [DLField]: 52 tall, radius 12, 1px
/// `borderStrong` on `surface`, 17px text, `textSecondary` placeholder; focus is
/// a 2px `accent` border, an error a 2px `danger` border plus the error line.
/// `multiline` is the 104-tall textarea, `amount` the 64-tall `.amt` field with
/// the `amountLg` style.
class DLTextField extends StatelessWidget {
  const DLTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.optionalLabel,
    this.hint,
    this.error,
    this.helper,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.multiline = false,
    this.amount = false,
    this.autofocus = false,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.maxLength,
    this.suffixIcon,
    this.bottomGap = DLSpace.s4,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? optionalLabel;
  final String? hint;
  final String? error;
  final String? helper;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// For read-only fields that open a picker (date, time).
  final VoidCallback? onTap;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool multiline;
  final bool amount;
  final bool autofocus;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final int? maxLength;

  /// 20px icon at the end of the field (calendar, clock).
  final IconData? suffixIcon;
  final double bottomGap;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    final hasError = error != null;
    final style = amount ? DLText.amountLg : DLText.textBodyLg;
    // 52 = 12 + 28px line + 12; the amount field is 64 = 16 + 32 + 16.
    final minHeight = multiline ? 104.0 : (amount ? 64.0 : DLSize.controlLg);
    final vPad = amount ? DLSpace.s4 : DLSpace.s3;
    final idle = hasError ? _border(c.danger, 2) : _border(c.borderStrong, 1);
    final focused = hasError ? _border(c.danger, 2) : _border(c.accent, 2);
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      enabled: enabled,
      readOnly: readOnly,
      onTap: onTap,
      obscureText: obscureText,
      maxLength: maxLength,
      keyboardType: keyboardType ?? (multiline ? TextInputType.multiline : (amount ? TextInputType.number : null)),
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      minLines: multiline ? 2 : null,
      maxLines: multiline ? null : 1,
      textAlignVertical: multiline ? TextAlignVertical.top : TextAlignVertical.center,
      style: style.copyWith(color: enabled ? c.textPrimary : c.textDisabled),
      cursorColor: c.accent,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: style.copyWith(color: c.textSecondary),
        filled: true,
        fillColor: enabled ? c.surface : c.surfaceSunken,
        isDense: true,
        counterText: '',
        constraints: BoxConstraints(minHeight: minHeight),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: vPad),
        border: idle,
        enabledBorder: idle,
        focusedBorder: focused,
        disabledBorder: _border(c.divider, 1),
        suffixIcon: suffixIcon == null ? null : Icon(suffixIcon, size: 20, color: c.textSecondary),
      ),
    );
    return DLField(
      label: label,
      optionalLabel: optionalLabel,
      error: error,
      helper: helper,
      bottomGap: bottomGap,
      child: field,
    );
  }
}

/// Select (prototype `.selw`): looks like [DLTextField] with a 20px chevron;
/// tapping opens a dropdown menu under the field (`surfaceRaised`, dropdown
/// shadow, selected item in `accentSoft` with a check).
class DLSelect<T> extends StatefulWidget {
  const DLSelect({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.label,
    this.optionalLabel,
    this.hint,
    this.error,
    this.helper,
    this.bottomGap = DLSpace.s4,
  });

  final T? value;
  final List<(T, String)> options;
  final ValueChanged<T>? onChanged;
  final String? label;
  final String? optionalLabel;
  final String? hint;
  final String? error;
  final String? helper;
  final double bottomGap;

  @override
  State<DLSelect<T>> createState() => _DLSelectState<T>();
}

class _DLSelectState<T> extends State<DLSelect<T>> {
  final _fieldKey = GlobalKey();
  bool _open = false;

  Future<void> _openMenu() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final box = _fieldKey.currentContext!.findRenderObject()! as RenderBox;
    final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
    final anchor = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    setState(() => _open = true);
    final picked = await navigator.push(
      _DLSelectRoute<T>(
        anchor: anchor,
        options: widget.options,
        value: widget.value,
        label: widget.label,
        barrierLabel: AppLocalizations.of(context).close,
        duration: DLMotion.of(context, DLMotion.fast),
      ),
    );
    if (!mounted) return;
    setState(() => _open = false);
    if (picked != null) widget.onChanged?.call(picked.$1);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    final enabled = widget.onChanged != null;
    String? selectedLabel;
    for (final (v, l) in widget.options) {
      if (v == widget.value) selectedLabel = l;
    }
    final border = widget.error != null
        ? Border.all(color: c.danger, width: 2)
        : _open
            ? Border.all(color: c.accent, width: 2)
            : Border.all(color: enabled ? c.borderStrong : c.divider);
    final text = selectedLabel ?? widget.hint ?? '';
    final box = DLPressable(
      key: _fieldKey,
      onTap: enabled ? _openMenu : null,
      scaleOnPress: false,
      semanticLabel: [if (widget.label != null) widget.label!, text].join(', '),
      excludeSemantics: true,
      borderRadius: _controlRadius,
      // Layout padding stays 1px-border based so the text never jumps.
      decoration: BoxDecoration(color: enabled ? c.surface : c.surfaceSunken, borderRadius: _controlRadius),
      child: CustomPaint(
        foregroundPainter: _BorderPainter(border: border),
        child: SizedBox(
          height: DLSize.controlLg,
          child: Padding(
            padding: const EdgeInsets.only(left: 14, right: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DLText.textBodyLg.copyWith(
                      color: !enabled ? c.textDisabled : (selectedLabel == null ? c.textSecondary : c.textPrimary),
                    ),
                  ),
                ),
                const SizedBox(width: DLSpace.s2),
                Icon(DLIcons.chevronDown, size: 20, color: c.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
    return DLField(
      label: widget.label,
      optionalLabel: widget.optionalLabel,
      error: widget.error,
      helper: widget.helper,
      bottomGap: widget.bottomGap,
      child: box,
    );
  }
}

/// Paints a [Border] around a radius-12 control without affecting layout.
class _BorderPainter extends CustomPainter {
  const _BorderPainter({required this.border});

  final Border border;

  @override
  void paint(Canvas canvas, Size size) => border.paint(canvas, Offset.zero & size, borderRadius: _controlRadius);

  @override
  bool shouldRepaint(_BorderPainter oldDelegate) => oldDelegate.border != border;
}

/// The dropdown of [DLSelect]. Pops with a one-field record so "nothing picked"
/// (null) is distinct from picking a null value.
class _DLSelectRoute<T> extends PopupRoute<(T,)> {
  _DLSelectRoute({
    required this.anchor,
    required this.options,
    required this.value,
    required this.label,
    required this.barrierLabel,
    required this.duration,
  });

  final Rect anchor;
  final List<(T, String)> options;
  final T? value;
  final String? label;
  final Duration duration;

  @override
  final String barrierLabel;

  static const double _itemHeight = DLSize.touch;
  static const double _maxHeight = 320;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => duration;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    final c = context.dl;
    final media = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final top = media.padding.top + DLSpace.s2;
        final bottom = constraints.maxHeight - math.max(media.padding.bottom, media.viewInsets.bottom) - DLSpace.s2;
        final below = bottom - (anchor.bottom + DLSpace.s1);
        final above = anchor.top - DLSpace.s1 - top;
        final wanted = math.min(options.length * _itemHeight + DLSpace.s2, _maxHeight);
        final down = below >= wanted || below >= above;
        final height = math.max(_itemHeight, math.min(wanted, down ? below : above));
        final menuTop = down ? anchor.bottom + DLSpace.s1 : anchor.top - DLSpace.s1 - height;
        return Stack(
          children: [
            Positioned(
              left: anchor.left,
              width: anchor.width,
              top: menuTop,
              height: height,
              child: FadeTransition(
                opacity: animation,
                child: Semantics(
                  scopesRoute: true,
                  namesRoute: true,
                  explicitChildNodes: true,
                  label: label,
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.surfaceRaised,
                      borderRadius: _controlRadius,
                      border: Border.all(color: c.divider),
                      boxShadow: DLShadows.dropdown(Theme.of(context).brightness),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(DLRadius.md - 1)),
                      child: ListView(
                        padding: const EdgeInsets.all(DLSpace.s1),
                        children: [
                          for (final (v, l) in options)
                            _MenuItem(label: l, selected: v == value, onTap: () => Navigator.pop(context, (v,))),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    const shape = BorderRadius.all(Radius.circular(DLRadius.sm));
    final fg = selected ? c.accentText : c.textPrimary;
    return DLPressable(
      onTap: onTap,
      selected: selected,
      scaleOnPress: false,
      borderRadius: shape,
      pressedColor: c.surfaceSunken,
      decoration: BoxDecoration(color: selected ? c.accentSoft : c.surfaceRaised.withValues(alpha: 0), borderRadius: shape),
      child: SizedBox(
        height: DLSize.touch,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DLSpace.s3),
          child: Row(
            children: [
              Expanded(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: DLText.textBodyLg.copyWith(color: fg)),
              ),
              if (selected) Icon(DLIcons.check, size: 20, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

/// Search bar (prototype `.srch`): 48 tall `surface` pill with the card shadow,
/// a search icon, 15px input and a clear button once there is text.
class DLSearchBar extends StatefulWidget {
  const DLSearchBar({super.key, required this.hint, this.controller, this.onChanged});

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  @override
  State<DLSearchBar> createState() => _DLSearchBarState();
}

class _DLSearchBarState extends State<DLSearchBar> {
  TextEditingController? _own;
  TextEditingController get _controller => widget.controller ?? (_own ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(DLSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _own)?.removeListener(_changed);
      _controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _own?.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    final t = AppLocalizations.of(context);
    final style = DLText.textBody.copyWith(color: c.textPrimary);
    return Container(
      height: DLSize.touch,
      padding: const EdgeInsets.only(left: DLSpace.s4, right: 6),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.all(Radius.circular(DLRadius.pill)),
        boxShadow: DLShadows.card(Theme.of(context).brightness),
      ),
      child: Row(
        children: [
          Icon(DLIcons.search, size: 20, color: c.textSecondary),
          const SizedBox(width: DLSpace.s2),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: widget.onChanged,
              textInputAction: TextInputAction.search,
              style: style,
              cursorColor: c.accent,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: style.copyWith(color: c.textSecondary),
                isDense: true,
                filled: false,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            DLIconButton(icon: DLIcons.close, tooltip: t.reset, onPressed: _clear, size: 40, iconSize: 20),
        ],
      ),
    );
  }
}

/// On/off switch (prototype `.sw`): 52×32 track, `borderStrong` off and
/// `actionPrimary` on, a 24px white knob (dark ground on the bright dark-theme
/// track). Lays out 48 tall for the touch target.
class DLSwitch extends StatelessWidget {
  const DLSwitch({super.key, required this.value, required this.onChanged, this.semanticLabel});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    final enabled = onChanged != null;
    final duration = DLMotion.of(context, DLMotion.fast);
    final track = !enabled ? c.surfaceSunken : (value ? c.actionPrimary : c.borderStrong);
    // `onBrand` is white in both themes: the prototype's `#fff` knob.
    final knob = !enabled ? c.textDisabled : (value ? c.onActionPrimary : c.onBrand);
    return DLPressable(
      onTap: enabled ? () => onChanged!(!value) : null,
      toggled: value,
      semanticLabel: semanticLabel,
      borderRadius: const BorderRadius.all(Radius.circular(DLRadius.pill)),
      child: SizedBox(
        width: 52,
        height: DLSize.touch,
        child: Center(
          child: AnimatedContainer(
            duration: duration,
            width: 52,
            height: 32,
            padding: const EdgeInsets.all(DLSpace.s1),
            decoration: BoxDecoration(color: track, borderRadius: const BorderRadius.all(Radius.circular(DLRadius.pill))),
            child: AnimatedAlign(
              duration: duration,
              curve: Curves.ease,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: AnimatedContainer(
                duration: duration,
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: knob, shape: BoxShape.circle),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Checkbox (prototype `.chk`): 24px, radius 7 (`round` = circle), 2px
/// `borderStrong`; checked is a `success` fill with an `onSuccess` check.
/// Lays out 48×48 for the touch target.
class DLCheckbox extends StatelessWidget {
  const DLCheckbox({super.key, required this.value, required this.onChanged, this.round = false, this.semanticLabel});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool round;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    final radius = BorderRadius.circular(round ? DLRadius.pill : 7);
    return DLPressable(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      toggled: value,
      semanticLabel: semanticLabel,
      borderRadius: const BorderRadius.all(Radius.circular(DLRadius.pill)),
      child: SizedBox.square(
        dimension: DLSize.touch,
        child: Center(
          child: AnimatedContainer(
            duration: DLMotion.of(context, DLMotion.fast),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: value ? c.success : c.success.withValues(alpha: 0),
              borderRadius: radius,
              border: Border.all(color: value ? c.success : c.borderStrong, width: 2),
            ),
            child: value ? Icon(DLIcons.check, size: 16, color: c.onSuccess) : null,
          ),
        ),
      ),
    );
  }
}
