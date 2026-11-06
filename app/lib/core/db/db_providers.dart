// Riverpod access to the database and its DAOs. `main()` overrides
// [appDatabaseProvider] with the on-device database; tests override it with
// `AppDatabase(NativeDatabase.memory())`.
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';
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

/// The database file in the app's documents directory, opened on a background
/// isolate the first time it's used.
AppDatabase openAppDatabase() => AppDatabase(LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      return NativeDatabase.createInBackground(File(p.join(dir.path, 'daily_life.sqlite')));
    }));

final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('appDatabaseProvider must be overridden in main()'),
);

final financeDaoProvider = Provider<FinanceDao>((ref) => ref.watch(appDatabaseProvider).financeDao);
final salaryDaoProvider = Provider<SalaryDao>((ref) => ref.watch(appDatabaseProvider).salaryDao);
final savingsDaoProvider = Provider<SavingsDao>((ref) => ref.watch(appDatabaseProvider).savingsDao);
final shopDaoProvider = Provider<ShopDao>((ref) => ref.watch(appDatabaseProvider).shopDao);
final workDaoProvider = Provider<WorkDao>((ref) => ref.watch(appDatabaseProvider).workDao);
final calendarDaoProvider = Provider<CalendarDao>((ref) => ref.watch(appDatabaseProvider).calendarDao);
final remindersDaoProvider = Provider<RemindersDao>((ref) => ref.watch(appDatabaseProvider).remindersDao);
final notesDaoProvider = Provider<NotesDao>((ref) => ref.watch(appDatabaseProvider).notesDao);
final healthDaoProvider = Provider<HealthDao>((ref) => ref.watch(appDatabaseProvider).healthDao);
final goalsDaoProvider = Provider<GoalsDao>((ref) => ref.watch(appDatabaseProvider).goalsDao);
final documentsDaoProvider = Provider<DocumentsDao>((ref) => ref.watch(appDatabaseProvider).documentsDao);
final inboxDaoProvider = Provider<InboxDao>((ref) => ref.watch(appDatabaseProvider).inboxDao);
