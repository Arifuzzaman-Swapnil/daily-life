import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'shop_dao.g.dart';

/// A payment larger than the shop's balance.
class ShopOverpayException implements Exception {
  const ShopOverpayException(this.balance);

  final int balance;

  @override
  String toString() => 'ShopOverpayException(balance: $balance)';
}

/// A shop in the Shop credit list.
class ShopSummary {
  const ShopSummary({required this.shop, required this.balance, this.lastType, this.lastDate});

  final Shop shop;

  /// Purchases − payments. Above 0 = money owed.
  final int balance;

  /// The most recently added entry, if any.
  final ShopEntryType? lastType;
  final DateTime? lastDate;
}

/// One entry in a shop's history with the balance after it.
class ShopEntryLine {
  const ShopEntryLine(this.entry, this.runningBalance);

  final ShopEntry entry;
  final int runningBalance;

  /// A payment that cleared the balance ("Full settlement"); other payments are
  /// partial.
  bool get settles => entry.type == ShopEntryType.pay && runningBalance <= 0;
}

/// Shop detail for a month: previous balance + purchases − paid = now due.
class ShopDetail {
  const ShopDetail({
    required this.shop,
    required this.previousBalance,
    required this.purchases,
    required this.paid,
    required this.balance,
    required this.entries,
  });

  final Shop shop;

  /// Balance from entries before the month.
  final int previousBalance;

  /// Purchases and payments dated in the month or later.
  final int purchases;
  final int paid;

  /// Now due.
  final int balance;

  /// Oldest first; the screen shows them newest first.
  final List<ShopEntryLine> entries;
}

@DriftAccessor(tables: [Shops, ShopEntries, Transactions])
class ShopDao extends DatabaseAccessor<AppDatabase> with _$ShopDaoMixin {
  ShopDao(super.attachedDatabase);

  static const _signed = "CASE WHEN type = 'buy' THEN amount ELSE -amount END";

  /// Shops in creation order, with balance and last entry.
  Stream<List<ShopSummary>> watchShops() => customSelect(
        '''
SELECT s.*,
  COALESCE((SELECT SUM($_signed) FROM shop_entries e WHERE e.shop_id = s.id), 0) AS balance,
  (SELECT e.type FROM shop_entries e WHERE e.shop_id = s.id ORDER BY e.rowid DESC LIMIT 1) AS last_type,
  (SELECT e.date FROM shop_entries e WHERE e.shop_id = s.id ORDER BY e.rowid DESC LIMIT 1) AS last_date
FROM shops s ORDER BY s.created_at''',
        readsFrom: {shops, shopEntries},
      ).watch().map((rows) => [
            for (final row in rows)
              ShopSummary(
                shop: shops.map(row.data),
                balance: row.read<int>('balance'),
                lastType: switch (row.readNullable<String>('last_type')) { final t? => ShopEntryType.values.byName(t), null => null },
                lastDate: switch (row.readNullable<String>('last_date')) { final d? => parseDayKey(d), null => null },
              ),
          ]);

  /// Total owed across shops with a balance, and how many shops that is.
  Stream<({int total, int shops})> watchTotalDue() => customSelect(
        '''
SELECT COALESCE(SUM(b), 0) AS total, COUNT(*) AS n FROM (
  SELECT SUM($_signed) AS b FROM shop_entries GROUP BY shop_id
) WHERE b > 0''',
        readsFrom: {shopEntries},
      ).watchSingle().map((r) => (total: r.read<int>('total'), shops: r.read<int>('n')));

  Future<int> balanceOf(String shopId) async {
    final row = await customSelect(
      'SELECT COALESCE(SUM($_signed), 0) AS b FROM shop_entries WHERE shop_id = ?1',
      variables: [Variable.withString(shopId)],
      readsFrom: {shopEntries},
    ).getSingle();
    return row.read<int>('b');
  }

  /// A shop's history and month summary; null once the shop is deleted.
  Stream<ShopDetail?> watchDetail(String shopId, DateTime month) {
    final monthStart = DayRange.month(month).start;
    return customSelect(
      'SELECT * FROM shop_entries WHERE shop_id = ?1 ORDER BY date, rowid',
      variables: [Variable.withString(shopId)],
      readsFrom: {shops, shopEntries},
    ).watch().asyncMap((rows) async {
      final shop = await (select(shops)..where((s) => s.id.equals(shopId))).getSingleOrNull();
      if (shop == null) return null;
      var running = 0, previous = 0, purchases = 0, paid = 0;
      final lines = <ShopEntryLine>[];
      for (final row in rows) {
        final e = shopEntries.map(row.data);
        final signed = e.type == ShopEntryType.buy ? e.amount : -e.amount;
        running += signed;
        if (dayKey(e.date).compareTo(monthStart) < 0) {
          previous += signed;
        } else if (e.type == ShopEntryType.buy) {
          purchases += e.amount;
        } else {
          paid += e.amount;
        }
        lines.add(ShopEntryLine(e, running));
      }
      return ShopDetail(shop: shop, previousBalance: previous, purchases: purchases, paid: paid, balance: running, entries: lines);
    });
  }

  /// Adds a shop. An [openingBalance] above 0 is recorded as a purchase named
  /// [openingItem] ("Previous balance"). Returns the shop id.
  Future<String> addShop(String name, {int openingBalance = 0, DateTime? date, String openingItem = ''}) {
    if (openingBalance < 0) throw ArgumentError.value(openingBalance, 'openingBalance', 'must not be negative');
    return transaction(() async {
      final id = newId();
      await into(shops).insert(ShopsCompanion.insert(id: Value(id), name: name));
      if (openingBalance > 0) {
        await into(shopEntries).insert(ShopEntriesCompanion.insert(
          shopId: id,
          type: ShopEntryType.buy,
          amount: openingBalance,
          date: dateOnly(date ?? DateTime.now()),
          item: Value(openingItem),
        ));
      }
      return id;
    });
  }

  Future<void> renameShop(String id, String name) =>
      (update(shops)..where((s) => s.id.equals(id))).write(ShopsCompanion(name: Value(name)));

  /// Deletes the shop and its entries. Its payment expenses stay, unlinked.
  Future<int> deleteShop(String id) => (delete(shops)..where((s) => s.id.equals(id))).go();

  /// A purchase on credit: raises the balance; not an expense. Returns the entry id.
  Future<String> addPurchase({required String shopId, required int amount, required DateTime date, String item = ''}) async {
    if (amount <= 0) throw ArgumentError.value(amount, 'amount', 'must be positive');
    final id = newId();
    await into(shopEntries).insert(ShopEntriesCompanion.insert(
      id: Value(id),
      shopId: shopId,
      type: ShopEntryType.buy,
      amount: amount,
      date: dateOnly(date),
      item: Value(item),
    ));
    return id;
  }

  /// A payment: lowers the balance and records an expense (category `shop`,
  /// linked to the shop), in one transaction. Paying more than the balance throws
  /// [ShopOverpayException] and writes nothing. [title] is the expense title in
  /// the current language ("Payment to …"). Returns the expense id.
  Future<String> pay({
    required String shopId,
    required int amount,
    required DateTime date,
    required PaymentMethod method,
    required String title,
    String time = '18:00',
  }) {
    if (amount <= 0) throw ArgumentError.value(amount, 'amount', 'must be positive');
    return transaction(() async {
      final balance = await balanceOf(shopId);
      if (amount > balance) throw ShopOverpayException(balance);
      final txId = newId();
      await into(transactions).insert(TransactionsCompanion.insert(
        id: Value(txId),
        type: TxType.expense,
        title: title,
        categoryId: kShopCategory,
        amount: amount,
        date: dateOnly(date),
        time: Value(time),
        paymentMethod: method,
        shopId: Value(shopId),
      ));
      await into(shopEntries).insert(ShopEntriesCompanion.insert(
        shopId: shopId,
        type: ShopEntryType.pay,
        amount: amount,
        date: dateOnly(date),
        transactionId: Value(txId),
      ));
      return txId;
    });
  }

  /// "Settle in full": pays the whole balance. Returns the expense id, or null
  /// when nothing is owed.
  Future<String?> settle({required String shopId, required DateTime date, required String title, PaymentMethod method = PaymentMethod.cash}) async {
    final balance = await balanceOf(shopId);
    if (balance <= 0) return null;
    return pay(shopId: shopId, amount: balance, date: date, method: method, title: title);
  }

  /// Deletes an entry. A payment goes together with its expense.
  Future<void> deleteEntry(String id) => transaction(() async {
        final e = await (select(shopEntries)..where((x) => x.id.equals(id))).getSingleOrNull();
        if (e == null) return;
        if (e.transactionId != null) {
          await (delete(transactions)..where((t) => t.id.equals(e.transactionId!))).go();
        }
        await (delete(shopEntries)..where((x) => x.id.equals(id))).go();
      });
}
