// Drift tables for every record in the brief's data model.
//
// Conventions:
// - Ids are text: `newId()` (uuid v4) for new rows; seeded rows keep the sample ids.
// - Amounts are whole taka (`int`).
// - Date-only columns use `DateOnlyConverter` (text `yyyy-MM-dd`); times of day are
//   text `HH:mm` (what `DLFormat.time` takes); timestamps are ISO-8601 text.
// - Enums are stored by name.
// - Text the person types is stored as typed. Built-in category names are not stored
//   (null): the UI shows the `cat_<id>` string.
import 'package:drift/drift.dart';

import 'converters.dart';
import 'enums.dart';

// ---------------------------------------------------------------- Money

/// Income and expense categories. `other` exists for both types, so the key is
/// (type, id). The system category `shop` (shop-credit payments) has `isSystem`
/// and is never offered in pickers.
@DataClassName('TxCategory')
class Categories extends Table {
  TextColumn get type => textEnum<TxType>()();
  TextColumn get id => text().clientDefault(newId)();

  /// Null for built-ins: the UI shows `cat_<id>`.
  TextColumn get name => text().nullable()();

  /// Icon key (prototype icon name, e.g. `cash`, `food`).
  TextColumn get icon => text()();

  /// `DLTone` name for the icon tile.
  TextColumn get tone => text()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {type, id};
}

@DataClassName('Txn')
class Transactions extends Table {
  TextColumn get id => text().clientDefault(newId)();
  TextColumn get type => textEnum<TxType>()();
  TextColumn get title => text()();

  /// Category id within [type] (see [Categories]).
  TextColumn get categoryId => text()();
  IntColumn get amount => integer()();
  TextColumn get date => text().map(const DateOnlyConverter())();
  TextColumn get time => text().withDefault(const Constant('12:00'))();
  TextColumn get paymentMethod => textEnum<PaymentMethod>()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get note => text().withDefault(const Constant(''))();

  /// Budget (allocation) row chosen on an expense.
  TextColumn get allocationId => text().nullable().references(AllocationCategories, #id, onDelete: KeyAction.setNull)();

  /// Set on the expense a shop-credit payment creates.
  TextColumn get shopId => text().nullable().references(Shops, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SalaryRecord')
class SalaryRecords extends Table {
  TextColumn get id => text().clientDefault(newId)();

  /// The month the salary is for (`yyyy-MM`).
  TextColumn get salaryMonth => text().map(const MonthConverter())();
  TextColumn get paidDate => text().map(const DateOnlyConverter())();
  IntColumn get amount => integer()();
  TextColumn get method => textEnum<PaymentMethod>()();
  TextColumn get note => text().withDefault(const Constant(''))();

  /// The income transaction recorded with it.
  TextColumn get transactionId => text().nullable().references(Transactions, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Single row (id 1): the expected monthly salary and next pay date.
@DataClassName('SalaryConfig')
class SalarySettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get monthlyAmount => integer().withDefault(const Constant(0))();
  TextColumn get nextExpectedDate => text().nullable().map(const DateOnlyConverter())();

  @override
  Set<Column> get primaryKey => {id};
}

/// Salary allocation (budget planning, not spending).
@DataClassName('Allocation')
class AllocationCategories extends Table {
  TextColumn get id => text().clientDefault(newId)();
  TextColumn get name => text().withDefault(const Constant(''))();
  IntColumn get amount => integer().withDefault(const Constant(0))();

  /// Expense category whose spending this row tracks, or `savings`
  /// (`kSavingsLink`) for this month's savings deposits.
  TextColumn get linkedCategoryId => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// `AllocationCategories.linkedCategoryId` value that tracks savings deposits.
const kSavingsLink = 'savings';

@DataClassName('SavingsGoal')
class SavingsGoals extends Table {
  TextColumn get id => text().clientDefault(newId)();
  TextColumn get name => text()();
  IntColumn get target => integer()();
  TextColumn get targetDate => text().map(const DateOnlyConverter())();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Savings deposits and withdrawals. Deposits are not expenses.
@DataClassName('SavingsEntry')
class SavingsEntries extends Table {
  TextColumn get id => text().clientDefault(newId)();
  TextColumn get type => textEnum<SavingsDirection>()();
  IntColumn get amount => integer()();
  TextColumn get date => text().map(const DateOnlyConverter())();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get goalId => text().nullable().references(SavingsGoals, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Shop')
class Shops extends Table {
  TextColumn get id => text().clientDefault(newId)();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Shop-credit entries. Balance = purchases − payments. Entries keep insertion
/// order (rowid) within a day for the running balance.
@DataClassName('ShopEntry')
class ShopEntries extends Table {
  TextColumn get id => text().clientDefault(newId)();
  TextColumn get shopId => text().references(Shops, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => textEnum<ShopEntryType>()();
  IntColumn get amount => integer()();
  TextColumn get date => text().map(const DateOnlyConverter())();

  /// What was bought (empty for payments).
  TextColumn get item => text().withDefault(const Constant(''))();

  /// For a payment: the expense it created. Deleting that expense deletes the
  /// payment, so the balance stays true.
  TextColumn get transactionId => text().nullable().references(Transactions, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------- Work

@DataClassName('Project')
class Projects extends Table {
  TextColumn get id => text().clientDefault(newId)();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Task')
class Tasks extends Table {
  TextColumn get id => text().clientDefault(newId)();
  TextColumn get title => text()();
  TextColumn get projectId => text().nullable().references(Projects, #id, onDelete: KeyAction.setNull)();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get date => text().map(const DateOnlyConverter())();
  TextColumn get startTime => text()();
  TextColumn get endTime => text()();
  TextColumn get status => textEnum<TaskStatus>()();
  TextColumn get priority => textEnum<PriorityLevel>()();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get spentMinutes => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Single row (id 1): the work timer, persisted so it survives restarts.
/// Elapsed = [accumulatedMs] + (now − [startedAt] while running).
@DataClassName('TimerSession')
class TimerSessions extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get taskId => text().nullable().references(Tasks, #id, onDelete: KeyAction.setNull)();
  TextColumn get state => textEnum<TimerState>()();
  IntColumn get accumulatedMs => integer().withDefault(const Constant(0))();
  DateTimeColumn get startedAt => dateTime().nullable()();

  /// Minutes logged by the last stop ("X logged").
  IntColumn get lastLoggedMinutes => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------- Planner

@DataClassName('Event')
class Events extends Table {
  TextColumn get id => text().clientDefault(newId)();
  TextColumn get title => text()();
  TextColumn get category => textEnum<EventCategory>()();
  TextColumn get startDate => text().map(const DateOnlyConverter())();
  TextColumn get endDate => text().map(const DateOnlyConverter())();

  /// Null for an all-day event.
  TextColumn get startTime => text().nullable()();
  TextColumn get endTime => text().nullable()();
  TextColumn get location => text().withDefault(const Constant(''))();

  /// 0 (none), 10, 30, 60 or 1440 minutes before.
  IntColumn get reminderMinutes => integer().withDefault(const Constant(0))();
  TextColumn get repeat => textEnum<RepeatRule>()();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Reminder')
class Reminders extends Table {
  TextColumn get id => text().clientDefault(newId)();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get date => text().map(const DateOnlyConverter())();
  TextColumn get time => text()();
  TextColumn get priority => textEnum<PriorityLevel>()();
  TextColumn get category => textEnum<ReminderCategory>()();
  TextColumn get repeat => textEnum<RepeatRule>()();

  /// Weekdays for a custom repeat (0 = Saturday … 6 = Friday).
  IntColumn get customDays => integer().withDefault(const Constant(0)).map(const WeekdaySetConverter())();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Note')
class Notes extends Table {
  TextColumn get id => text().clientDefault(newId)();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get body => text().withDefault(const Constant(''))();
  TextColumn get category => textEnum<NoteCategory>()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------- Health

/// A glass of water. The brief lists only a time; the date makes daily history
/// (reports, last 7 days) possible. The daily target is a preference.
@DataClassName('WaterEntry')
class WaterEntries extends Table {
  TextColumn get id => text().clientDefault(newId)();
  TextColumn get date => text().map(const DateOnlyConverter())();
  TextColumn get time => text()();
  IntColumn get ml => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Meal')
class Meals extends Table {
  TextColumn get id => text().clientDefault(newId)();
  TextColumn get type => textEnum<MealType>()();
  TextColumn get date => text().map(const DateOnlyConverter())();
  TextColumn get time => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get note => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Habit')
class Habits extends Table {
  TextColumn get id => text().clientDefault(newId)();
  TextColumn get name => text()();

  /// Icon key (prototype icon name, e.g. `book`, `flame`).
  TextColumn get icon => text().withDefault(const Constant('flame'))();
  TextColumn get reminderTime => text().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}

/// A day on which a habit was done.
@DataClassName('HabitCheck')
class HabitChecks extends Table {
  TextColumn get habitId => text().references(Habits, #id, onDelete: KeyAction.cascade)();
  TextColumn get date => text().map(const DateOnlyConverter())();

  @override
  Set<Column> get primaryKey => {habitId, date};
}

// ---------------------------------------------------------------- Goals, documents, inbox

@DataClassName('Goal')
class Goals extends Table {
  TextColumn get id => text().clientDefault(newId)();
  TextColumn get title => text()();
  TextColumn get category => textEnum<GoalCategory>()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get targetDate => text().map(const DateOnlyConverter())();
  BoolColumn get achieved => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Milestone')
class Milestones extends Table {
  TextColumn get id => text().clientDefault(newId)();
  TextColumn get goalId => text().references(Goals, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Document')
class Documents extends Table {
  TextColumn get id => text().clientDefault(newId)();
  TextColumn get title => text()();
  TextColumn get category => textEnum<DocCategory>()();
  TextColumn get kind => textEnum<DocKind>()();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get uploadedAt => dateTime().clientDefault(DateTime.now)();

  /// The app's private copy of the file. Null for sample documents (no file).
  TextColumn get filePath => text().nullable()();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  IntColumn get pages => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}

/// The in-app notification list (Home → bell).
@DataClassName('InboxItem')
class InboxItems extends Table {
  TextColumn get id => text().clientDefault(newId)();

  /// Icon key (prototype icon name, e.g. `bell`, `drop`).
  TextColumn get icon => text()();

  /// `DLTone` name.
  TextColumn get tone => text()();
  TextColumn get title => text()();
  TextColumn get body => text().withDefault(const Constant(''))();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();

  /// Where tapping it goes (a prototype screen id, e.g. `reminders`).
  TextColumn get route => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}
