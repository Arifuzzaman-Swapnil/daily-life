import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';
import '../../core/format/format_provider.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import 'notes_providers.dart';
import 'notes_screen.dart';

/// A note (prototype `noteDetail`, screenshot 57): pin, archive, delete, edit.
/// Archiving unpins it.
class NoteDetailScreen extends ConsumerWidget {
  const NoteDetailScreen({super.key, required this.id});

  final String id;

  Future<void> _pin(BuildContext context, WidgetRef ref, Note n) async {
    final t = AppLocalizations.of(context);
    await ref.read(notesDaoProvider).setPinned(n.id, !n.pinned);
    if (context.mounted) DLToast.show(context, n.pinned ? t.noteUnpinned : t.notePinned);
  }

  Future<void> _archive(BuildContext context, WidgetRef ref, Note n) async {
    final t = AppLocalizations.of(context);
    final dao = ref.read(notesDaoProvider);
    await dao.setArchived(n.id, !n.archived);
    if (!n.archived) await dao.setPinned(n.id, false);
    if (context.mounted) DLToast.show(context, n.archived ? t.noteUnarch : t.noteArchived);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Note n, String title) async {
    final t = AppLocalizations.of(context);
    final ok = await showDLConfirm(context, title: t.delNoteQ, body: title);
    if (!ok || !context.mounted) return;
    await ref.read(notesDaoProvider).deleteNote(n.id);
    if (!context.mounted) return;
    DLToast.show(context, t.noteDeleted);
    popOr(context, Routes.notes);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final n = ref.watch(noteProvider(id)).value;
    final title = n == null || n.title.isEmpty ? t.noteDetail : n.title;

    final actions = n == null
        ? const <Widget>[]
        : [
            DLIconButton(icon: DLIcons.pin, tooltip: n.pinned ? t.unpin : t.pin, tonal: n.pinned, onPressed: () => _pin(context, ref, n)),
            DLIconButton(icon: DLIcons.archive, tooltip: n.archived ? t.unarchive : t.archive, onPressed: () => _archive(context, ref, n)),
            DLIconButton(icon: DLIcons.trash, tooltip: t.del, onPressed: () => _delete(context, ref, n, title)),
          ];
    final appBar = DLAppBar(title: t.noteDetail, actions: actions, onLeading: () => popOr(context, Routes.notes));
    if (n == null) return Scaffold(appBar: appBar, body: const SizedBox.shrink());

    return Scaffold(
      appBar: appBar,
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          Wrap(
            spacing: DLSpace.s2,
            runSpacing: DLSpace.s1,
            children: [
              DLTag(label: noteCategoryLabel(t, n.category), tone: noteTone(n.category)),
              if (n.pinned) DLTag(label: t.pinned, icon: DLIcons.pin),
              if (n.archived) DLTag(label: t.archived, tone: DLTone.neutral),
            ],
          ),
          const SizedBox(height: DLSpace.s3),
          Text(title, style: DLText.textH1.copyWith(color: c.textPrimary)),
          const SizedBox(height: DLSpace.s1),
          Text(
            '${t.created} ${f.dateMedium(n.createdAt)} · ${t.updatedL} ${f.dateMedium(n.updatedAt)}',
            style: DLText.textBodySm.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: DLSpace.s4),
          Text(n.body, style: DLText.textBodyLg.copyWith(height: 30 / 17, color: c.textPrimary)),
          const SizedBox(height: DLSpace.s8),
          Row(
            children: [
              Expanded(
                child: DLButton(
                  label: n.archived ? t.unarchive : t.archive,
                  icon: DLIcons.archive,
                  variant: DLButtonVariant.secondary,
                  onPressed: () => _archive(context, ref, n),
                ),
              ),
              const SizedBox(width: DLSpace.s2),
              Expanded(child: DLButton(label: t.edit, icon: DLIcons.edit, onPressed: () => context.push(Routes.editNote(n.id)))),
            ],
          ),
        ],
      ),
    );
  }
}
