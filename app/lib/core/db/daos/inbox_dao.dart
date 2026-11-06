import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'inbox_dao.g.dart';

/// The in-app notification list.
@DriftAccessor(tables: [InboxItems])
class InboxDao extends DatabaseAccessor<AppDatabase> with _$InboxDaoMixin {
  InboxDao(super.attachedDatabase);

  /// Newest first.
  Stream<List<InboxItem>> watchItems() => (select(inboxItems)..orderBy([(i) => OrderingTerm.desc(i.createdAt)])).watch();

  Stream<int> watchUnreadCount() => customSelect(
        'SELECT COUNT(*) AS n FROM inbox_items WHERE is_read = 0',
        readsFrom: {inboxItems},
      ).watchSingle().map((r) => r.read<int>('n'));

  Future<String> addItem({required String icon, required String tone, required String title, String body = '', String route = ''}) async {
    final id = newId();
    await into(inboxItems).insert(InboxItemsCompanion.insert(id: Value(id), icon: icon, tone: tone, title: title, body: Value(body), route: Value(route)));
    return id;
  }

  Future<void> markRead(String id) =>
      (update(inboxItems)..where((i) => i.id.equals(id))).write(const InboxItemsCompanion(isRead: Value(true)));

  Future<void> markAllRead() => update(inboxItems).write(const InboxItemsCompanion(isRead: Value(true)));

  Future<int> deleteItem(String id) => (delete(inboxItems)..where((i) => i.id.equals(id))).go();
}
