import 'package:flutter/material.dart';

import '../theme/dl_tokens.dart';
import 'dl_motion.dart';

/// Segmented tabs (prototype `.seg`): a `surfaceSunken` well with 4px padding;
/// the selected segment is a raised `surfaceRaised` pill with the card shadow
/// and `textPrimary` label, the others `textSecondary`.
///
/// `expand: true` shares the width equally (Income / Expense, report tabs);
/// `expand: false` hugs the labels (the "৬ মাস / ১২ মাস" switch).
/// Each segment's touch area reaches the well's edges, so the control is 48 tall.
class DLSegmentedTabs<T> extends StatelessWidget {
  const DLSegmentedTabs({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.expand = true,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T>? onChanged;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    final shadow = DLShadows.card(Theme.of(context).brightness);
    final duration = DLMotion.of(context, DLMotion.fast);
    final last = options.length - 1;
    Widget segment(int i, T option, String label) {
      final on = option == value;
      final seg = DLPressable(
        onTap: onChanged == null ? null : () => onChanged!(option),
        selected: on,
        borderRadius: const BorderRadius.all(Radius.circular(DLRadius.sm)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(i == 0 ? DLSpace.s1 : 2, DLSpace.s1, i == last ? DLSpace.s1 : 2, DLSpace.s1),
          child: AnimatedContainer(
            duration: duration,
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: on ? c.surfaceRaised : c.surfaceRaised.withValues(alpha: 0),
              borderRadius: const BorderRadius.all(Radius.circular(DLRadius.sm)),
              boxShadow: on ? shadow : const [],
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: DLText.textLabel.copyWith(color: on ? c.textPrimary : c.textSecondary),
              ),
            ),
          ),
        ),
      );
      return expand ? Expanded(child: seg) : seg;
    }

    return DecoratedBox(
      decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: const BorderRadius.all(Radius.circular(DLRadius.md))),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [for (final (i, (option, label)) in options.indexed) segment(i, option, label)],
      ),
    );
  }
}
