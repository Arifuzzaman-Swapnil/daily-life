// Riverpod access to notes and the Notebook screen's own state (prototype
// `noteArch`, `noteCat`, `noteQ`).
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';

@immutable
class NoteFilter {
  const NoteFilter({this.archived = false, this.category, this.search = ''});

  /// Showing the archive instead of the notebook.
  final bool archived;

  /// Null = all categories.
  final NoteCategory? category;
  final String search;

  bool get isFiltered => category != null || search.trim().isNotEmpty;
}

final noteFilterProvider = NotifierProvider<NoteFilterController, NoteFilter>(NoteFilterController.new);

class NoteFilterController extends Notifier<NoteFilter> {
  @override
  NoteFilter build() => const NoteFilter();

  void toggleArchive() => state = NoteFilter(archived: !state.archived, category: state.category, search: state.search);

  void showNotebook() => state = NoteFilter(category: state.category, search: state.search);

  void setCategory(NoteCategory? c) => state = NoteFilter(archived: state.archived, category: c, search: state.search);

  void setSearch(String s) => state = NoteFilter(archived: state.archived, category: state.category, search: s);
}

/// The notes the Notebook shows: pinned first, then most recently edited.
final notesProvider = StreamProvider<List<Note>>((ref) {
  final f = ref.watch(noteFilterProvider);
  return ref.watch(notesDaoProvider).watchNotes(archived: f.archived, category: f.category, search: f.search);
});

/// Whether any note exists, archived included (the "still empty" state).
final anyNotesProvider = StreamProvider<bool>((ref) => ref.watch(notesDaoProvider).watchTotalCount().map((n) => n > 0));

/// Notes not archived (More's subtitle).
final activeNotesCountProvider = StreamProvider<int>((ref) => ref.watch(notesDaoProvider).watchActiveCount());

/// One note; null once deleted.
final noteProvider = StreamProvider.family<Note?, String>((ref, id) => ref.watch(notesDaoProvider).watchNote(id));
