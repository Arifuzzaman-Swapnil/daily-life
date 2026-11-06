import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';
import '../../core/format/dl_format_more.dart';
import '../../core/format/format_provider.dart';
import '../../core/prefs/app_settings.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import 'calendar_providers.dart';
import 'calendar_ui.dart';

/// Event details (prototype `eventDetail`, screenshot 45): when, where, the
/// reminder and the repeat; edit and delete.
class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.id});

  final String id;

  Future<void> _delete(BuildContext context, WidgetRef ref, Event e) async {
    final t = AppLocalizations.of(context);
    final f = ref.read(formatProvider);
    final ok = await showDLConfirm(context, title: t.delEventQ, body: '${e.title} · ${f.dateMedium(e.startDate)}');
    if (!ok || !context.mounted) return;
    await ref.read(calendarDaoProvider).deleteEvent(e.id);
    if (!context.mounted) return;
    DLToast.show(context, t.eventDeleted);
    popOr(context, Routes.calendar);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final showBangla = ref.watch(settingsProvider.select((s) => s.banglaDate));
    final e = ref.watch(eventProvider(id)).value;

    void edit(Event e) => context.push(Routes.editEvent(e.id));
    final actions = e == null
        ? const <Widget>[]
        : [
            DLIconButton(icon: DLIcons.edit, tooltip: t.edit, onPressed: () => edit(e)),
            DLIconButton(icon: DLIcons.trash, tooltip: t.del, onPressed: () => _delete(context, ref, e)),
          ];
    final appBar = DLAppBar(title: t.eventDetail, actions: actions, onLeading: () => popOr(context, Routes.calendar));
    if (e == null) return Scaffold(appBar: appBar, body: const SizedBox.shrink());

    Widget fact(IconData icon, DLTone tone, List<Widget> lines) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DLIconChip(icon: icon, tone: tone, size: 36),
            const SizedBox(width: DLSpace.s3),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines),
              ),
            ),
          ],
        );
    Text body(String s) => Text(s, style: DLText.textBody.copyWith(color: c.textPrimary));
    Text sub(String s) => Text(s, style: DLText.textBodySm.copyWith(color: c.textSecondary));

    final facts = <Widget>[
      fact(DLIcons.calendar, DLTone.accent, [
        body(f.dateLongYear(e.startDate)),
        sub(eventTime(t, f, e)),
        if (showBangla) sub(f.bangla(e.startDate)),
      ]),
      if (e.location.isNotEmpty) fact(DLIcons.mapPin, DLTone.teal, [body(e.location)]),
      fact(DLIcons.bell, DLTone.warning, [body('${t.reminder}: ${reminderLabel(t, e.reminderMinutes)}')]),
      fact(DLIcons.repeat, DLTone.neutral, [body('${t.repeat}: ${repeatLabel(t, e.repeat)}')]),
    ];

    return Scaffold(
      appBar: appBar,
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          DLCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DLTag(label: eventCategoryLabel(t, e.category), tone: eventTone(e.category)),
                const SizedBox(height: DLSpace.s3),
                Text(e.title, style: DLText.textH2.copyWith(color: c.textPrimary)),
                for (final w in facts) ...[const SizedBox(height: DLSpace.s3), w],
                if (e.description.isNotEmpty) ...[
                  const SizedBox(height: DLSpace.s3),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: DLSpace.s3),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: c.divider))),
                    child: Text(e.description, style: DLText.textBody.copyWith(color: c.textSecondary)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: DLSpace.s4),
          Row(
            children: [
              Expanded(
                child: DLButton(
                  label: t.del,
                  icon: DLIcons.trash,
                  variant: DLButtonVariant.secondary,
                  onPressed: () => _delete(context, ref, e),
                ),
              ),
              const SizedBox(width: DLSpace.s2),
              Expanded(child: DLButton(label: t.edit, icon: DLIcons.edit, onPressed: () => edit(e))),
            ],
          ),
        ],
      ),
    );
  }
}
