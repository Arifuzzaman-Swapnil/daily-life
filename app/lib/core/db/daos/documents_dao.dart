import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'documents_dao.g.dart';

@DriftAccessor(tables: [Documents])
class DocumentsDao extends DatabaseAccessor<AppDatabase> with _$DocumentsDaoMixin {
  DocumentsDao(super.attachedDatabase);

  /// Newest first; optionally one category and/or matching [search] in title and description.
  Stream<List<Document>> watchDocuments({DocCategory? category, String search = ''}) {
    final q = select(documents);
    if (category != null) q.where((d) => d.category.equalsValue(category));
    final s = search.trim();
    if (s.isNotEmpty) q.where((d) => d.title.like('%$s%') | d.description.like('%$s%'));
    q.orderBy([(d) => OrderingTerm.desc(d.createdAt)]);
    return q.watch();
  }

  /// Documents per category.
  Stream<Map<DocCategory, int>> watchCounts() => customSelect(
        'SELECT category, COUNT(*) AS n FROM documents GROUP BY category',
        readsFrom: {documents},
      ).watch().map((rows) => {for (final r in rows) DocCategory.values.byName(r.read<String>('category')): r.read<int>('n')});

  Future<Document?> documentById(String id) => (select(documents)..where((d) => d.id.equals(id))).getSingleOrNull();

  /// Inserts [row] and returns its id.
  Future<String> addDocument(DocumentsCompanion row) async {
    final id = row.id.present ? row.id.value : newId();
    await into(documents).insert(row.copyWith(id: Value(id)));
    return id;
  }

  Future<bool> updateDocument(Document row) => update(documents).replace(row);

  /// Deletes the row; the caller removes the stored file.
  Future<int> deleteDocument(String id) => (delete(documents)..where((d) => d.id.equals(id))).go();
}
