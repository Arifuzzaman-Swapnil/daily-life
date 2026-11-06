// The app's SQLite database (drift). Generated code: app_database.g.dart and
// daos/*.g.dart, produced by build_runner in CI (not committed).
import 'package:drift/drift.dart';

import 'converters.dart';
import 'daos/calendar_dao.dart';
import 'daos/documents_dao.dart';
import 'daos/finance_dao.dart';
import 'daos/goals_dao.dart';
import 'daos/health_dao.dart';
import 'daos/inbox_dao.dart';
import 'daos/notes_dao.dart';
import 'daos/reminders_dao.dart';
import 'daos/salary_dao.dart';
import 'daos/savings_dao.dart';
import 'daos/shop_dao.dart';
import 'daos/work_dao.dart';
import 'enums.dart';
import 'tables.dart';

export 'converters.dart';
export 'enums.dart';
export 'tables.dart' show kSavingsLink;

part 'app_database.g.dart';

/// A built-in category: (id, icon key, `DLTone` name). Order = picker order.
typedef _Builtin = (String id, String icon, String tone);

/// The prototype's `CATS`, including the system `shop` category.
const _builtinIncome = <_Builtin>[
  ('salary', 'cash', 'success'),
  ('bonus', 'gift', 'success'),
  ('freelance', 'laptop', 'accent'),
  ('extra', 'brief', 'teal'),
  ('business', 'store', 'warning'),
  ('other', 'dots', 'neutral'),
];
const _builtinExpense = <_Builtin>[
  ('food', 'food', 'neutral'),
  ('transport', 'bus', 'neutral'),
  ('rent', 'home', 'neutral'),
  ('shopping', 'bag', 'neutral'),
  ('family', 'heart', 'neutral'),
  ('personal', 'user', 'neutral'),
  ('medical', 'med', 'neutral'),
  ('ent', 'film', 'neutral'),
  ('mobile', 'wifi', 'neutral'),
  (kShopCategory, 'store', 'neutral'),
  ('other', 'dots', 'neutral'),
];

/// Category id of shop-credit payments (system category, expense type).
const kShopCategory = 'shop';

/// Category id of salary income.
const kSalaryCategory = 'salary';

@DriftDatabase(
  tables: [
    Categories,
    Transactions,
    SalaryRecords,
    SalarySettings,
    AllocationCategories,
    SavingsGoals,
    SavingsEntries,
    Shops,
    ShopEntries,
    Projects,
    Tasks,
    TimerSessions,
    Events,
    Reminders,
    Notes,
    WaterEntries,
    Meals,
    Habits,
    HabitChecks,
    Goals,
    Milestones,
    Documents,
    InboxItems,
  ],
  daos: [
    FinanceDao,
    SalaryDao,
    SavingsDao,
    ShopDao,
    WorkDao,
    CalendarDao,
    RemindersDao,
    NotesDao,
    HealthDao,
    GoalsDao,
    DocumentsDao,
    InboxDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Before the first real release a schema change bumps this and the upgrade
  /// recreates every table (test installs only hold sample data). From the first
  /// release on, write step-by-step migrations instead.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await insertDefaults();
        },
        onUpgrade: (m, from, to) async {
          await customStatement('PRAGMA foreign_keys = OFF');
          for (final entity in allSchemaEntities.toList().reversed) {
            await m.drop(entity);
          }
          await m.createAll();
          await insertDefaults();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          // Android's sandbox may not allow SQLite's default temp directory.
          await customStatement('PRAGMA temp_store = MEMORY');
        },
      );

  /// Rows every database starts with: the built-in categories and the single
  /// salary-settings and timer rows.
  Future<void> insertDefaults() async {
    await batch((b) {
      b.insertAll(categories, [
        for (final (i, c) in _builtinIncome.indexed)
          CategoriesCompanion.insert(type: TxType.income, id: Value(c.$1), icon: c.$2, tone: c.$3, isDefault: const Value(true), sortOrder: Value(i)),
        for (final (i, c) in _builtinExpense.indexed)
          CategoriesCompanion.insert(
            type: TxType.expense,
            id: Value(c.$1),
            icon: c.$2,
            tone: c.$3,
            isDefault: const Value(true),
            isSystem: Value(c.$1 == kShopCategory),
            sortOrder: Value(i),
          ),
      ]);
      b.insert(salarySettings, const SalarySettingsCompanion(id: Value(1)), mode: InsertMode.insertOrIgnore);
      b.insert(timerSessions, const TimerSessionsCompanion(id: Value(1), state: Value(TimerState.idle)), mode: InsertMode.insertOrIgnore);
    });
  }

  /// The data tables the sample-data toggle fills and clears (everything except
  /// categories and the single settings/timer rows).
  List<TableInfo<Table, Object?>> get dataTables => [
        shopEntries,
        transactions,
        salaryRecords,
        allocationCategories,
        savingsEntries,
        savingsGoals,
        shops,
        tasks,
        projects,
        events,
        reminders,
        notes,
        waterEntries,
        meals,
        habitChecks,
        habits,
        milestones,
        goals,
        documents,
        inboxItems,
      ];

  /// True when any data table has a row.
  Future<bool> hasAnyData() async {
    final exists = dataTables.map((t) => 'EXISTS(SELECT 1 FROM "${t.actualTableName}")').join(' OR ');
    final row = await customSelect('SELECT ($exists) AS any_data', readsFrom: dataTables.toSet()).getSingle();
    return row.read<bool>('any_data');
  }
}
