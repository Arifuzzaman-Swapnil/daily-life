import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/format_provider.dart';
import '../../core/prefs/app_settings.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';

/// Build-step-1 stand-in for a root tab. Shows the localized tab title and a
/// card of formatted values so language, digit, date and theme switching is
/// visible on every tab. Each feature step replaces its tab with the real screen.
class TabPlaceholder extends ConsumerWidget {
  const TabPlaceholder({super.key, required this.title, this.actions = const [], this.children = const []});

  final String title;
  final List<Widget> actions;
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final showBangla = ref.watch(settingsProvider.select((s) => s.banglaDate));
    final today = ref.watch(clockProvider)();
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Column(
      children: [
        DLAppBar.root(title: title, actions: actions),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + bottom),
            children: [
              DLCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.dateLong(today), style: DLText.textH3.copyWith(color: c.textPrimary)),
                    if (showBangla) Text(f.bangla(today), style: DLText.textBodySm.copyWith(color: c.textSecondary)),
                    const SizedBox(height: DLSpace.s3),
                    Text(f.taka(125000), style: DLText.amountLg.copyWith(color: c.textPrimary)),
                    const SizedBox(height: DLSpace.s1),
                    Text(
                      '${f.dateMedium(today)} · ${f.time('09:30')} · ${f.percent(65)}',
                      style: DLText.textBodySm.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              ...children,
            ],
          ),
        ),
      ],
    );
  }
}
