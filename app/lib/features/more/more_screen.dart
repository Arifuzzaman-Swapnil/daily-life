import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../shell/tab_placeholder.dart';

/// More tab. Build step 1 only links to Settings; the other modules arrive in step 6.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    return TabPlaceholder(
      title: t.more,
      children: [
        DLSectionHeader(t.settings),
        DLList(
          children: [
            DLListRow(
              leading: const DLIconChip(icon: DLIcons.gear, size: 36),
              title: t.settings,
              subtitle: t.setSubM,
              trailing: Icon(DLIcons.chevronRight, size: 20, color: c.textSecondary),
              onTap: () => context.push(Routes.settings),
            ),
          ],
        ),
      ],
    );
  }
}
