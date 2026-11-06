import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_basics.dart';
import '../../core/widgets/dl_icons.dart';
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
        DLCardBox(
          padding: EdgeInsets.zero,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => context.push(Routes.settings),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DLSpace.s4, vertical: DLSpace.s3),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(10)),
                        child: Icon(DLIcons.gear, size: 20, color: c.textPrimary),
                      ),
                      const SizedBox(width: DLSpace.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.settings, style: DLText.textBody.copyWith(color: c.textPrimary)),
                            Text(t.setSubM, style: DLText.textBodySm.copyWith(color: c.textSecondary)),
                          ],
                        ),
                      ),
                      Icon(DLIcons.chevronRight, size: 20, color: c.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
