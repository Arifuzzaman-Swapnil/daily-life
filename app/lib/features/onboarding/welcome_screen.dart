import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/dl_format.dart';
import '../../core/prefs/app_settings.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';

/// First launch (prototype `welcome`, screenshot 01): a language switch, the
/// logo, what the app does, the tagline and "Get started".
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final lang = ref.watch(settingsProvider.select((s) => s.lang));
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: DLAppBar.height,
              child: Padding(
                padding: const EdgeInsets.only(right: DLSpace.s2),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 180,
                    child: DLSegmentedTabs<AppLang>(
                      value: lang,
                      options: const [(AppLang.bn, 'বাংলা'), (AppLang.en, 'English')],
                      onChanged: ref.read(settingsProvider.notifier).setLanguage,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(DLSpace.s4, 0, DLSpace.s4, DLSpace.s6 + bottom),
                    sliver: SliverFillRemaining(
                      hasScrollBody: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: DLSpace.s6),
                          const Align(alignment: Alignment.centerLeft, child: DLLogo(size: 72)),
                          const SizedBox(height: DLSpace.s4),
                          Semantics(header: true, child: Text(t.welcomeT, style: DLText.textDisplay.copyWith(color: c.textPrimary))),
                          const SizedBox(height: DLSpace.s1),
                          Text(t.welcomeSub, style: DLText.textBodyLg.copyWith(color: c.textSecondary)),
                          const SizedBox(height: DLSpace.s8),
                          DLList(
                            children: [
                              for (final (icon, tone, label) in [
                                (DLIcons.wallet, DLTone.accent, t.f1),
                                (DLIcons.calendar, DLTone.teal, t.f2),
                                (DLIcons.drop, DLTone.success, t.f3),
                              ])
                                ConstrainedBox(
                                  constraints: const BoxConstraints(minHeight: 64),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: DLSpace.s4, vertical: DLSpace.s3),
                                    child: Row(
                                      children: [
                                        DLIconChip(icon: icon, tone: tone),
                                        const SizedBox(width: DLSpace.s3),
                                        Expanded(child: Text(label, style: DLText.textBody.copyWith(color: c.textPrimary))),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: DLSpace.s6),
                          Text(t.tagline, textAlign: TextAlign.center, style: DLText.textLabel.copyWith(color: c.accentText)),
                          const Spacer(),
                          const SizedBox(height: DLSpace.s6),
                          DLButton(
                            label: t.getStarted,
                            trailingIcon: DLIcons.chevronRight,
                            onPressed: () => context.push(Routes.onboarding),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
