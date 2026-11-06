import 'package:dailylife/core/db/app_database.dart';
import 'package:dailylife/core/db/daos/shop_dao.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

final nov = DateTime(2026, 11);

void main() {
  late AppDatabase db;
  late ShopDao dao;
  late String shop;

  // The brief's example: previous ৳1,200 + purchase ৳300 − payment ৳500 = ৳1,000 due.
  setUp(() async {
    db = memoryDatabase();
    dao = db.shopDao;
    shop = await dao.addShop('Mayer Doa Store', openingBalance: 1200, date: DateTime(2026, 10, 20), openingItem: 'Previous balance');
    await dao.addPurchase(shopId: shop, amount: 300, date: DateTime(2026, 11, 3), item: 'Eggs and bread');
  });
  tearDown(() => db.close());

  Future<String> pay(int amount) => dao.pay(
        shopId: shop,
        amount: amount,
        date: DateTime(2026, 11, 5),
        method: PaymentMethod.cash,
        title: 'Payment to Mayer Doa Store',
      );

  test('a purchase raises the balance and is not an expense', () async {
    expect(await dao.balanceOf(shop), 1500);
    expect((await db.financeDao.monthTotals(nov)).expense, 0);
    expect(await db.financeDao.transactionsIn(), isEmpty);
  });

  test('a payment lowers the balance and records a shop expense', () async {
    final txId = await pay(500);
    expect(await dao.balanceOf(shop), 1000);

    final tx = (await db.financeDao.transactionById(txId))!;
    expect(tx.type, TxType.expense);
    expect(tx.categoryId, kShopCategory);
    expect(tx.shopId, shop);
    expect(tx.amount, 500);
    expect(tx.date, DateTime(2026, 11, 5));
    expect((await db.financeDao.monthTotals(nov)).expense, 500);
  });

  test('shop detail: previous + purchases − paid = now due, with running balances', () async {
    await pay(500);
    final d = (await dao.watchDetail(shop, nov).first)!;
    expect(d.shop.name, 'Mayer Doa Store');
    expect((d.previousBalance, d.purchases, d.paid, d.balance), (1200, 300, 500, 1000));
    expect(d.entries.map((l) => l.runningBalance), [1200, 1500, 1000]);
    expect(d.entries.map((l) => l.entry.item), ['Previous balance', 'Eggs and bread', '']);
    expect(d.entries.last.settles, isFalse); // partial payment
  });

  test('paying more than the balance is rejected and writes nothing', () async {
    await expectLater(pay(1501), throwsA(isA<ShopOverpayException>().having((e) => e.balance, 'balance', 1500)));
    expect(await dao.balanceOf(shop), 1500);
    expect(await db.financeDao.transactionsIn(), isEmpty);
    expect(() => pay(0), throwsArgumentError);
  });

  test('settle in full clears the balance and is a full settlement', () async {
    await pay(500);
    expect(await dao.watchTotalDue().first, (total: 1000, shops: 1));

    final txId = await dao.settle(shopId: shop, date: DateTime(2026, 11, 6), title: 'Payment to Mayer Doa Store');
    expect(txId, isNotNull);
    expect(await dao.balanceOf(shop), 0);
    final d = (await dao.watchDetail(shop, nov).first)!;
    expect(d.entries.last.settles, isTrue);
    expect(await dao.watchTotalDue().first, (total: 0, shops: 0));
    expect(await dao.settle(shopId: shop, date: DateTime(2026, 11, 6), title: 'x'), isNull);
    expect((await db.financeDao.monthTotals(nov)).expense, 1500);
  });

  test('shop list shows balance and the last entry', () async {
    final other = await dao.addShop('Salam Tea Stall');
    final list = await dao.watchShops().first;
    expect(list.map((s) => s.shop.id), [shop, other]);
    expect(list.first.balance, 1500);
    expect(list.first.lastType, ShopEntryType.buy);
    expect(list.first.lastDate, DateTime(2026, 11, 3));
    expect(list.last.balance, 0);
    expect(list.last.lastType, isNull);
  });

  test('deleting the payment expense removes the payment; deleting the shop keeps the expense', () async {
    final txId = await pay(500);
    await db.financeDao.deleteTransaction(txId);
    expect(await dao.balanceOf(shop), 1500);

    final tx2 = await pay(200);
    await dao.deleteShop(shop);
    expect(await dao.watchShops().first, isEmpty);
    final kept = (await db.financeDao.transactionById(tx2))!;
    expect(kept.shopId, isNull);
    expect(kept.categoryId, kShopCategory);
  });

  test('deleting a payment entry deletes its expense too', () async {
    final txId = await pay(500);
    final d = (await dao.watchDetail(shop, nov).first)!;
    await dao.deleteEntry(d.entries.last.entry.id);
    expect(await db.financeDao.transactionById(txId), isNull);
    expect(await dao.balanceOf(shop), 1500);
  });
}
