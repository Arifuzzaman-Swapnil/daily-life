import 'package:flutter/material.dart';

import '../theme/dl_tokens.dart';
import 'dl_buttons.dart';
import 'dl_card.dart';

/// Empty state (prototype `.empty`): an 80px `accentSoft` halo with a 32px
/// `accentText` icon, an `textH3` title saying what is missing, a
/// `textSecondary` line saying what happens next, and a medium button.
/// `inCard` puts it on a card (`.card.empty`), as on most list screens.
class DLEmptyState extends StatelessWidget {
  const DLEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.actionVariant = DLButtonVariant.primary,
    this.inCard = false,
  });

  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;
  final DLButtonVariant actionVariant;
  final bool inCard;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: DLSpace.s4, vertical: DLSpace.s10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: c.accentText),
          ),
          const SizedBox(height: DLSpace.s4),
          Semantics(
            header: true,
            child: Text(title, textAlign: TextAlign.center, style: DLText.textH3.copyWith(color: c.textPrimary)),
          ),
          if (body != null) ...[
            const SizedBox(height: DLSpace.s2),
            Text(body!, textAlign: TextAlign.center, style: DLText.textBody.copyWith(color: c.textSecondary)),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: DLSpace.s4),
            DLButton(
              label: actionLabel!,
              icon: actionIcon,
              onPressed: onAction,
              variant: actionVariant,
              size: DLButtonSize.md,
              expand: false,
            ),
          ],
        ],
      ),
    );
    return inCard ? DLCard(padding: EdgeInsets.zero, child: SizedBox(width: double.infinity, child: content)) : content;
  }
}
