import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'notes_dao.g.dart';

@DriftAccessor(tables: [Notes])
class NotesDao extends DatabaseAccessor<AppDatabase> with _$NotesDaoMixin {
  NotesDao(super.attachedDatabase);

  /// Notes, pinned first, then most recently edited. [search] matches title and body.
  Stream<List<Note>> watchNotes({bool archived = false, NoteCategory? category, String search = ''}) {
    final q = select(notes)..where((n) => n.archived.equals(archived));
    if (category != null) q.where((n) => n.category.equalsValue(category));
    final s = search.trim();
    if (s.isNotEmpty) q.where((n) => n.title.like('%$s%') | n.body.like('%$s%'));
    q.orderBy([(n) => OrderingTerm.desc(n.pinned), (n) => OrderingTerm.desc(n.updatedAt)]);
    return q.watch();
  }

  /// Notes not archived (the More screen's count).
  Stream<int> watchActiveCount() => customSelect(
        'SELECT COUNT(*) AS n FROM notes WHERE archived = 0',
        readsFrom: {notes},
      ).watchSingle().map((r) => r.read<int>('n'));

  /// Every note, archived included (the Notebook's "still empty" state).
  Stream<int> watchTotalCount() => customSelect(
        'SELECT COUNT(*) AS n FROM notes',
        readsFrom: {notes},
      ).watchSingle().map((r) => r.read<int>('n'));

  Future<Note?> noteById(String id) => (select(notes)..where((n) => n.id.equals(id))).getSingleOrNull();

  Stream<Note?> watchNote(String id) => (select(notes)..where((n) => n.id.equals(id))).watchSingleOrNull();

  /// Inserts [row] and returns its id.
  Future<String> addNote(NotesCompanion row) async {
    final id = row.id.present ? row.id.value : newId();
    await into(notes).insert(row.copyWith(id: Value(id)));
    return id;
  }

  /// Saves edits and stamps [Note.updatedAt].
  Future<void> updateNote(Note row, {DateTime? now}) => update(notes).replace(row.copyWith(updatedAt: now ?? DateTime.now()));

  Future<int> deleteNote(String id) => (delete(notes)..where((n) => n.id.equals(id))).go();

  Future<void> setPinned(String id, bool pinned) =>
      (update(notes)..where((n) => n.id.equals(id))).write(NotesCompanion(pinned: Value(pinned)));

  Future<void> setArchived(String id, bool archived) =>
      (update(notes)..where((n) => n.id.equals(id))).write(NotesCompanion(archived: Value(archived)));
}
