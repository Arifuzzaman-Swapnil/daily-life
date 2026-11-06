import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/db_providers.dart';
import '../../core/format/dl_format_more.dart';
import '../../core/format/format_provider.dart';
import '../../core/prefs/app_settings.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../notes/notes_providers.dart';
import '../reminders/reminders_providers.dart';

/// The app's version, as in pubspec.yaml (keep the two in step).
const appVersion = '0.1.0';

/// Goals not yet achieved (More's subtitle).
final _activeGoalsProvider = StreamProvider<int>(
  (ref) => ref.watch(goalsDaoProvider).watchGoals().map((l) => l.where((g) => !g.goal.achieved).length),
);

/// Every document.
final _documentCountProvider = StreamProvider<int>(
  (ref) => ref.watch(documentsDaoProvider).watchCounts().map((m) => m.values.fold(0, (a, b) => a + b)),
);

/// The More tab (prototype `more`, screenshot 50): the profile card, then
/// Planning, Lifestyle, Records & insights and Settings.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final (name, avatarColor) = ref.watch(settingsProvider.select((s) => (s.displayName, s.avatar)));
    final dark = Theme.of(context).brightness == Brightness.dark;
    final due = ref.watch(remDueProvider).value ?? 0;
    final notes = ref.watch(activeNotesCountProvider).value ?? 0;
    final goals = ref.watch(_activeGoalsProvider).value ?? 0;
    final docs = ref.watch(_documentCountProvider).value ?? 0;
    final bottom = MediaQuery.paddingOf(context).bottom;

    Widget row(IconData icon, DLTone tone, String label, String sub, String? route, {int badge = 0}) => DLListRow(
          leading: DLIconChip(icon: icon, tone: tone),
          title: label,
          titleStyle: DLText.textBodyLg,
          subtitle: sub,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (badge > 0) ...[DLBadge(f.count(badge)), const SizedBox(width: DLSpace.s2)],
              Icon(DLIcons.chevronRight, size: 20, color: c.textSecondary),
            ],
          ),
          onTap: route == null ? null : () => context.push(route),
        );

    final groups = [
      (t.planner, [
        row(DLIcons.bell, DLTone.warning, t.reminders, t.remSubM(f.count(due)), Routes.reminders, badge: due),
        row(DLIcons.note, DLTone.teal, t.notebook, t.noteSubM(f.count(notes)), Routes.notes),
      ]),
      (t.lifestyle, [
        row(DLIcons.pulse, DLTone.success, t.health, t.healthSubM, Routes.health),
        row(DLIcons.target, DLTone.accent, t.goalsT, t.goalSubM(f.count(goals)), Routes.goals),
      ]),
      (t.vault, [
        row(DLIcons.folder, DLTone.neutral, t.docs, t.docSubM(f.count(docs)), Routes.documents),
        row(DLIcons.chart, DLTone.accent, t.reports, t.repSubM, Routes.reports),
      ]),
      (t.settings, [row(DLIcons.gear, DLTone.neutral, t.settings, t.setSubM, Routes.settings)]),
    ];

    return Column(
      children: [
        DLAppBar.root(
          title: t.more,
          actions: [
            DLIconButton(
              icon: dark ? DLIcons.sun : DLIcons.moon,
              tooltip: t.toggleTheme,
              onPressed: () => ref.read(settingsProvider.notifier).setThemeMode(dark ? ThemeMode.light : ThemeMode.dark),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s8 + bottom),
            children: [
              DLCard(
                onTap: () => context.push(Routes.settings),
                child: Row(
                  children: [
                    DLAvatar(name: name, color: avatarColor),
                    const SizedBox(width: DLSpace.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? t.profile : name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DLText.textH3.copyWith(color: c.textPrimary),
                          ),
                          Text(t.localOnly, style: DLText.textBodySm.copyWith(color: c.textSecondary)),
                        ],
                      ),
                    ),
                    Icon(DLIcons.chevronRight, size: 20, color: c.textSecondary),
                  ],
                ),
              ),
              for (final (label, rows) in groups) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(DLSpace.s1, DLSpace.s5, DLSpace.s1, DLSpace.s2),
                  child: Semantics(
                    header: true,
                    child: Text(label, style: DLText.textBodySm.copyWith(fontWeight: FontWeight.w600, color: c.textSecondary)),
                  ),
                ),
                DLList(children: rows),
              ],
              const SizedBox(height: DLSpace.s6),
              Text(
                'Daily Life · ${t.version} ${f.digitsOf(appVersion)}',
                textAlign: TextAlign.center,
                style: DLText.textCaption.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
