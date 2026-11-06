// Riverpod access to documents and the Documents screen's category filter and
// search (prototype `docCat`, `docQ`).
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';

@immutable
class DocFilter {
  const DocFilter({this.category, this.search = ''});

  /// Null = every category.
  final DocCategory? category;
  final String search;
}

final docFilterProvider = NotifierProvider<DocFilterController, DocFilter>(DocFilterController.new);

class DocFilterController extends Notifier<DocFilter> {
  @override
  DocFilter build() => const DocFilter();

  /// Tapping the selected category again shows every document.
  void toggleCategory(DocCategory c) => state = DocFilter(category: state.category == c ? null : c, search: state.search);

  void setSearch(String s) => state = DocFilter(category: state.category, search: s);

  void reset() => state = const DocFilter();
}

/// The documents the list shows, newest first.
final documentsProvider = StreamProvider<List<Document>>((ref) {
  final f = ref.watch(docFilterProvider);
  return ref.watch(documentsDaoProvider).watchDocuments(category: f.category, search: f.search);
});

/// Documents per category (the category cards), and whether any exist.
final docCountsProvider = StreamProvider<Map<DocCategory, int>>((ref) => ref.watch(documentsDaoProvider).watchCounts());

/// One document; null once deleted.
final documentProvider = StreamProvider.family<Document?, String>((ref, id) => ref.watch(documentsDaoProvider).watchDocument(id));
