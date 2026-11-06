import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import '../../core/format/dl_format_more.dart';
import '../../core/format/format_provider.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import 'notes_providers.dart';

String noteCategoryLabel(AppLocalizations t, NoteCategory c) => switch (c) {
      NoteCategory.personal => t.nc_personal,
      NoteCategory.office => t.nc_office,
      NoteCategory.ideas => t.nc_ideas,
      NoteCategory.important => t.nc_important,
      NoteCategory.other => t.nc_other,
    };

DLTone noteTone(NoteCategory c) => switch (c) {
      NoteCategory.personal => DLTone.teal,
      NoteCategory.office => DLTone.accent,
      NoteCategory.ideas => DLTone.warning,
      NoteCategory.important => DLTone.danger,
      NoteCategory.other => DLTone.neutral,
    };

/// The Notebook (prototype `notes`, screenshot 55; empty 93): search,
/// categories, pinned and other notes in two columns, and the archive.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  late final _search = TextEditingController(text: ref.read(noteFilterProvider).search);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final filter = ref.watch(noteFilterProvider);
    final ctl = ref.read(noteFilterProvider.notifier);
    final notes = ref.watch(notesProvider).value;
    final any = ref.watch(anyNotesProvider).value ?? true;
    final bottom = MediaQuery.paddingOf(context).bottom;
    void write() => context.push(Routes.newNote);

    final sections = filter.archived
        ? [(t.archived, DLIcons.archive, notes ?? const <Note>[])]
        : [
            (t.pinned, DLIcons.pin, [for (final n in notes ?? const <Note>[]) if (n.pinned) n]),
            (t.otherNotes, DLIcons.note, [for (final n in notes ?? const <Note>[]) if (!n.pinned) n]),
          ];

    return Scaffold(
      appBar: DLAppBar(
        title: t.notebook,
        onLeading: () => popOr(context, Routes.more),
        actions: [
          DLIconButton(icon: DLIcons.archive, tooltip: t.archived, tonal: filter.archived, onPressed: ctl.toggleArchive),
        ],
      ),
      floatingActionButton: DLFab(icon: DLIcons.edit, tooltip: t.newNote, onPressed: write),
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, bottom + DLSize.fab + DLSpace.s8),
        children: [
          DLSearchBar(hint: t.searchNotes, controller: _search, onChanged: ctl.setSearch),
          const SizedBox(height: DLSpace.s2),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (i, (cat, label)) in [(null, t.all), for (final x in NoteCategory.values) (x, noteCategoryLabel(t, x))].indexed) ...[
                  if (i > 0) const SizedBox(width: DLSpace.s2),
                  DLChip(label: label, selected: filter.category == cat, onTap: () => ctl.setCategory(cat)),
                ],
              ],
            ),
          ),
          if (filter.archived) ...[
            const SizedBox(height: DLSpace.s2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: DLSpace.s3, vertical: DLSpace.s2),
              decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(DLRadius.sm)),
              child: Row(
                children: [
                  Icon(DLIcons.archive, size: 16, color: c.textPrimary),
                  const SizedBox(width: DLSpace.s2),
                  Expanded(child: Text(t.archived, style: DLText.textLabel.copyWith(color: c.textPrimary))),
                ],
              ),
            ),
          ],
          if (notes != null && notes.isEmpty) ...[
            const SizedBox(height: DLSpace.s4),
            DLEmptyState(
              inCard: true,
              icon: DLIcons.note,
              title: !any
                  ? t.noNotes
                  : filter.archived && !filter.isFiltered
                      ? t.noArch
                      : t.noResults,
              body: !any ? t.noNotesSub : t.noMatchSub,
              actionLabel: !any ? t.newNote : null,
              onAction: !any ? write : null,
            ),
          ],
          for (final (label, icon, items) in sections)
            if (items.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(DLSpace.s1, DLSpace.s4, DLSpace.s1, DLSpace.s2),
                child: Semantics(
                  header: true,
                  child: Row(
                    children: [
                      Icon(icon, size: 16, color: c.textSecondary),
                      const SizedBox(width: DLSpace.s1),
                      Text(label, style: DLText.textBodySm.copyWith(fontWeight: FontWeight.w600, color: c.textSecondary)),
                    ],
                  ),
                ),
              ),
              _NoteGrid(notes: items),
            ],
        ],
      ),
    );
  }
}

/// Two columns of note cards, each row as tall as its taller card.
class _NoteGrid extends StatelessWidget {
  const _NoteGrid({required this.notes});

  final List<Note> notes;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < notes.length; i += 2) ...[
          if (i > 0) const SizedBox(height: DLSpace.s3),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _NoteCard(note: notes[i])),
                const SizedBox(width: DLSpace.s3),
                Expanded(child: i + 1 < notes.length ? _NoteCard(note: notes[i + 1]) : const SizedBox.shrink()),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A note card (prototype `.card.col`, min 128 tall): title and pin, three
/// lines of the body, category tag and last-edited date.
class _NoteCard extends ConsumerWidget {
  const _NoteCard({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final n = note;
    return DLCard(
      onTap: () => context.push(Routes.note(n.id)),
      padding: const EdgeInsets.all(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    n.title.isEmpty ? t.noteDetail : n.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DLText.textBody.copyWith(fontWeight: FontWeight.w600, color: c.textPrimary),
                  ),
                ),
                if (n.pinned) ...[
                  const SizedBox(width: DLSpace.s1),
                  Padding(padding: const EdgeInsets.only(top: 4), child: Icon(DLIcons.pin, size: 16, color: c.accentText)),
                ],
              ],
            ),
            const SizedBox(height: DLSpace.s2),
            Text(n.body, maxLines: 3, overflow: TextOverflow.ellipsis, style: DLText.textBodySm.copyWith(color: c.textSecondary)),
            const Spacer(),
            const SizedBox(height: DLSpace.s2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: DLTag(label: noteCategoryLabel(t, n.category), tone: noteTone(n.category))),
                const SizedBox(width: DLSpace.s2),
                Text(f.dateShort(n.updatedAt), style: DLText.textCaption.copyWith(color: c.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
