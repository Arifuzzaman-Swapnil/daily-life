// Minimal token-based building blocks for build step 1. Build step 2 replaces these
// with the full shared DL component set (AppBar, Card, ListRow, SegmentedTabs, …).
import 'package:flutter/material.dart';

import '../theme/dl_tokens.dart';

/// Root-tab title bar (prototype `.ab.top`): 64 tall, 26px bold title, trailing actions.
class DLRootTitleBar extends StatelessWidget {
  const DLRootTitleBar({super.key, required this.title, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.only(left: DLSpace.s4, right: DLSpace.s2),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(title, style: DLText.textH1.copyWith(color: c.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// 48dp round icon button with a localized tooltip (prototype `.ib`).
class DLIconButton extends StatelessWidget {
  const DLIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: DLSize.icon),
      color: c.textPrimary,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(DLSize.touch),
        fixedSize: const Size.square(DLSize.touch),
        highlightColor: c.surfaceSunken,
      ),
    );
  }
}

/// Section header above a card or list (prototype `.dh`).
class DLSectionHeader extends StatelessWidget {
  const DLSectionHeader(this.text, {super.key, this.first = false});

  final String text;
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

/// `surface` card with 16 radius and the resting card shadow (prototype `.card` / `.lst`).
class DLCardBox extends StatelessWidget {
  const DLCardBox({super.key, required this.child, this.padding = const EdgeInsets.all(DLSpace.s4)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.all(Radius.circular(DLRadius.lg)),
        boxShadow: DLShadows.card(Theme.of(context).brightness),
      ),
      clipBehavior: Clip.antiAlias,
      padding: padding,
      child: child,
    );
  }
}

/// Hairline between rows inside a list card.
class DLRowDivider extends StatelessWidget {
  const DLRowDivider({super.key});

  @override
  Widget build(BuildContext context) => Divider(height: 1, thickness: 1, color: context.dl.divider);
}
