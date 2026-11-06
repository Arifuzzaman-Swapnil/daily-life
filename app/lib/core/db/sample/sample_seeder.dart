// Loads the prototype's sample data (assets/sample_data.json, copied unchanged
// from daily-life-kit/data/) into the database.
//
// Bilingual sample text is given as `[bn, en]`. Seeding stores the text of the
// current language; [SampleSeeder.relocalize] later swaps untouched sample text
// to the other language, so sample data follows the language as it does in the
// prototype, while anything the person edited stays as typed.
import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:drift/drift.dart';

import '../../../l10n/app_localizations.dart';
import '../../format/dl_format.dart';
import '../app_database.dart';

typedef Json = Map<String, dynamic>;

/// One bilingual sample value stored in [column] of the row [id] in [table].
class _Slot {
  const _Slot(this.table, this.id, this.column, this.bn, this.en);

  final TableInfo<Table, Object?> table;
  final String id;
  final String column;
  final String bn;
  final String en;
}

class SampleSeeder {
  SampleSeeder(this.db, this.data);

  final AppDatabase db;
  final Json data;

  static Json parse(String source) => jsonDecode(source) as Json;

  /// The day the sample data is written around (2026-11-06).
  DateTime get today => parseDayKey(data['today'] as String);

  List<Json> _list(String key) => (data[key] as List).cast<Json>();

  static String _pick(Object? v, AppLang lang) => switch (v) {
        List<dynamic> pair => pair[lang == AppLang.bn ? 0 : 1] as String,
        String s => s,
        _ => '',
      };

  static DateTime _day(Object? v) => parseDayKey(v as String);

  /// Prototype tone class → `DLTone` name.
  static String _tone(String cls) => switch (cls) {
        't-su' => 'success',
        't-ac' => 'accent',
        't-ct' => 'teal',
        't-wa' => 'warning',
        't-da' => 'danger',
        _ => 'neutral',
      };

  static const _taskStatus = {'todo': TaskStatus.todo, 'prog': TaskStatus.inProgress, 'done': TaskStatus.done, 'hold': TaskStatus.onHold};
  static const _timerState = {'idle': TimerState.idle, 'run': TimerState.running, 'pause': TimerState.paused, 'stopped': TimerState.stopped};

  static AppLocalizations _l10n(AppLang lang) => lookupAppLocalizations(Locale(lang.name));

  /// Built-in habit names are string keys (`h_read` …).
  static String _habitName(String key, AppLocalizations l) => switch (key) {
        'h_read' => l.h_read,
        'h_ex' => l.h_ex,
        'h_learn' => l.h_learn,
        'h_walk' => l.h_walk,
        'h_sleep' => l.h_sleep,
        'h_wake' => l.h_wake,
        _ => key,
      };

  /// "240 KB" / "1.2 MB" → bytes.
  static int _bytes(String size) {
    final m = RegExp(r'([\d.]+)\s*(KB|MB|GB|B)', caseSensitive: false).firstMatch(size);
    if (m == null) return 0;
    final n = double.parse(m[1]!);
    final unit = m[2]!.toUpperCase();
    final mult = unit == 'GB' ? 1 << 30 : unit == 'MB' ? 1 << 20 : unit == 'KB' ? 1 << 10 : 1;
    return (n * mult).round();
  }

  /// A stable creation time for seeded row [i] (later rows are newer, or older
  /// when [newestFirst]), so lists keep the prototype's order.
  DateTime _stamp(int i, {bool newestFirst = false}) => today.add(Duration(hours: 12, seconds: newestFirst ? -i : i));

  /// The id of the transaction a salary record or shop payment created, matched
  /// by category, date and amount (the JSON doesn't link them).
  String? _linkedTx(String category, String date, int amount, {String? shop}) {
    for (final x in _list('tx')) {
      if (x['cat'] == category && x['date'] == date && x['amount'] == amount && (shop == null || x['shop'] == shop)) {
        return x['id'] as String;
      }
    }
    return null;
  }

  /// Empties the data tables and resets the salary and timer rows. Categories
  /// (built-in and custom) stay.
  static Future<void> clearData(AppDatabase db) => db.transaction(() => _clear(db));

  static Future<void> _clear(AppDatabase db) async {
    for (final t in db.dataTables) {
      await db.delete(t).go();
    }
    await (db.update(db.salarySettings)..where((s) => s.id.equals(1)))
        .write(const SalarySettingsCompanion(monthlyAmount: Value(0), nextExpectedDate: Value(null)));
    await (db.update(db.timerSessions)..where((t) => t.id.equals(1))).write(const TimerSessionsCompanion(
          taskId: Value(null),
          state: Value(TimerState.idle),
          accumulatedMs: Value(0),
          startedAt: Value(null),
          lastLoggedMinutes: Value(0),
        ));
  }

  /// Replaces all data with the sample data, in [lang].
  Future<void> seed(AppLang lang) => db.transaction(() async {
        await _clear(db);
        final l10n = _l10n(lang);
        String t(Object? v) => _pick(v, lang);

        // Parents before children: foreign keys are checked per statement.
        await db.batch((b) {
          b.insertAll(db.allocationCategories, [
            for (final (i, a) in _list('alloc').indexed)
              AllocationCategoriesCompanion.insert(
                id: Value(a['id'] as String),
                name: Value(t(a['name'])),
                amount: Value(a['amount'] as int),
                linkedCategoryId: Value(a['cat'] as String?),
                sortOrder: Value(i),
              ),
          ]);
          b.insertAll(db.shops, [
            for (final (i, s) in _list('shops').indexed)
              ShopsCompanion.insert(id: Value(s['id'] as String), name: t(s['name']), createdAt: Value(_stamp(i))),
          ]);
          b.insertAll(db.transactions, [
            for (final x in _list('tx'))
              TransactionsCompanion.insert(
                id: Value(x['id'] as String),
                type: TxType.values.byName(x['type'] as String),
                title: t(x['title']),
                categoryId: x['cat'] as String,
                amount: x['amount'] as int,
                date: _day(x['date']),
                time: Value(x['time'] as String),
                paymentMethod: PaymentMethod.values.byName(x['pm'] as String),
                description: Value(t(x['desc'])),
                note: Value(t(x['note'])),
                shopId: Value(x['shop'] as String?),
              ),
          ]);
          b.insertAll(db.shopEntries, [
            for (final s in _list('shops'))
              for (final e in (s['ent'] as List).cast<Json>())
                ShopEntriesCompanion.insert(
                  id: Value(e['id'] as String),
                  shopId: s['id'] as String,
                  type: ShopEntryType.values.byName(e['type'] as String),
                  amount: e['amount'] as int,
                  date: _day(e['date']),
                  item: Value(t(e['item'])),
                  transactionId: Value(
                    e['type'] == 'pay' ? _linkedTx(kShopCategory, e['date'] as String, e['amount'] as int, shop: s['id'] as String) : null,
                  ),
                ),
          ]);

          final salary = data['salary'] as Json;
          b.update(
            db.salarySettings,
            SalarySettingsCompanion(monthlyAmount: Value(salary['amount'] as int), nextExpectedDate: Value(_day(salary['next']))),
            where: (s) => s.id.equals(1),
          );
          b.insertAll(db.salaryRecords, [
            for (final (i, r) in (salary['recs'] as List).cast<Json>().indexed)
              SalaryRecordsCompanion.insert(
                id: Value(r['id'] as String),
                salaryMonth: _day(r['month']),
                paidDate: _day(r['paid']),
                amount: r['amount'] as int,
                method: PaymentMethod.values.byName(r['pm'] as String),
                note: Value(t(r['note'])),
                transactionId: Value(_linkedTx(kSalaryCategory, r['paid'] as String, r['amount'] as int)),
                createdAt: Value(_stamp(i, newestFirst: true)),
              ),
          ]);

          b.insertAll(db.savingsGoals, [
            for (final (i, g) in _list('sgoals').indexed)
              SavingsGoalsCompanion.insert(
                id: Value(g['id'] as String),
                name: t(g['name']),
                target: g['target'] as int,
                targetDate: _day(g['date']),
                createdAt: Value(_stamp(i)),
              ),
          ]);
          b.insertAll(db.savingsEntries, [
            for (final (i, v) in _list('sav').indexed)
              SavingsEntriesCompanion.insert(
                id: Value(v['id'] as String),
                type: v['type'] == 'out' ? SavingsDirection.withdrawal : SavingsDirection.deposit,
                amount: v['amount'] as int,
                date: _day(v['date']),
                note: Value(t(v['note'])),
                goalId: Value(v['goal'] as String?),
                createdAt: Value(_stamp(i)),
              ),
          ]);

          b.insertAll(db.projects, [
            for (final (i, p) in _list('projects').indexed)
              ProjectsCompanion.insert(
                id: Value(p['id'] as String),
                name: t(p['name']),
                description: Value(t(p['desc'])),
                createdAt: Value(_stamp(i)),
              ),
          ]);
          b.insertAll(db.tasks, [
            for (final (i, k) in _list('tasks').indexed)
              TasksCompanion.insert(
                id: Value(k['id'] as String),
                title: t(k['title']),
                projectId: Value(k['proj'] as String?),
                description: Value(t(k['desc'])),
                date: _day(k['date']),
                startTime: k['start'] as String,
                endTime: k['end'] as String,
                status: _taskStatus[k['status']] ?? TaskStatus.todo,
                priority: PriorityLevel.values.byName(k['pri'] as String),
                note: Value(t(k['note'])),
                spentMinutes: Value(k['spent'] as int? ?? 0),
                createdAt: Value(_stamp(i, newestFirst: true)),
              ),
          ]);
          final timer = data['timer'] as Json;
          b.update(
            db.timerSessions,
            TimerSessionsCompanion(
              taskId: Value(timer['task'] as String?),
              state: Value(_timerState[timer['st']] ?? TimerState.idle),
              accumulatedMs: Value(timer['acc'] as int? ?? 0),
              startedAt: const Value(null),
              lastLoggedMinutes: const Value(0),
            ),
            where: (s) => s.id.equals(1),
          );

          b.insertAll(db.events, [
            for (final (i, e) in _list('events').indexed)
              EventsCompanion.insert(
                id: Value(e['id'] as String),
                title: t(e['title']),
                category: EventCategory.values.byName(e['cat'] as String),
                startDate: _day(e['date']),
                endDate: _day(e['end'] ?? e['date']),
                startTime: Value((e['start'] as String?)?.isEmpty ?? true ? null : e['start'] as String),
                endTime: Value((e['fin'] as String?)?.isEmpty ?? true ? null : e['fin'] as String),
                location: Value(t(e['loc'])),
                reminderMinutes: Value(int.tryParse('${e['rem']}') ?? 0),
                repeat: RepeatRule.values.byName(e['rep'] as String),
                description: Value(t(e['desc'])),
                createdAt: Value(_stamp(i)),
              ),
          ]);
          b.insertAll(db.reminders, [
            for (final (i, r) in _list('rems').indexed)
              RemindersCompanion.insert(
                id: Value(r['id'] as String),
                title: t(r['title']),
                description: Value(t(r['desc'])),
                date: _day(r['date']),
                time: r['time'] as String,
                priority: PriorityLevel.values.byName(r['pri'] as String),
                category: ReminderCategory.values.byName(r['cat'] as String),
                repeat: RepeatRule.values.byName(r['rep'] as String),
                customDays: Value({for (final d in (r['days'] as List?) ?? const []) d as int}),
                enabled: Value(r['on'] as bool? ?? true),
                done: Value(r['done'] as bool? ?? false),
                createdAt: Value(_stamp(i)),
              ),
          ]);
          b.insertAll(db.notes, [
            for (final n in _list('notes'))
              NotesCompanion.insert(
                id: Value(n['id'] as String),
                title: Value(t(n['title'])),
                body: Value(t(n['body'])),
                category: NoteCategory.values.byName(n['cat'] as String),
                pinned: Value(n['pin'] as bool? ?? false),
                archived: Value(n['arch'] as bool? ?? false),
                createdAt: Value(_day(n['created'])),
                updatedAt: Value(_day(n['updated'])),
              ),
          ]);

          // Today's glasses, plus one entry per earlier day of the 7-day history
          // (`wHist[0]` is six days ago; the last slot is today, from `water`).
          b.insertAll(db.waterEntries, [
            for (final w in _list('water'))
              WaterEntriesCompanion.insert(id: Value(w['id'] as String), date: today, time: w['t'] as String, ml: w['ml'] as int),
            for (final (i, ml) in (data['wHist'] as List).cast<int>().take(6).indexed)
              if (ml > 0)
                WaterEntriesCompanion.insert(
                  id: Value('wh$i'),
                  date: DateTime(today.year, today.month, today.day - (6 - i)),
                  time: '12:00',
                  ml: ml,
                ),
          ]);
          b.insertAll(db.meals, [
            for (final m in _list('meals'))
              MealsCompanion.insert(
                id: Value(m['id'] as String),
                type: MealType.values.byName(m['type'] as String),
                date: _day(m['date']),
                time: m['time'] as String,
                description: Value(t(m['desc'])),
                note: Value(t(m['note'])),
              ),
          ]);
          b.insertAll(db.habits, [
            for (final (i, h) in _list('habits').indexed)
              HabitsCompanion.insert(
                id: Value(h['id'] as String),
                name: _habitName(h['name'] as String, l10n),
                icon: Value(h['icon'] as String),
                reminderTime: Value(h['time'] as String?),
                createdAt: Value(_stamp(i)),
              ),
          ]);
          b.insertAll(
            db.habitChecks,
            [
              for (final h in _list('habits'))
                for (final d in (h['days'] as List).cast<String>()) HabitChecksCompanion.insert(habitId: h['id'] as String, date: parseDayKey(d)),
            ],
            mode: InsertMode.insertOrIgnore,
          );

          b.insertAll(db.goals, [
            for (final (i, g) in _list('goals').indexed)
              GoalsCompanion.insert(
                id: Value(g['id'] as String),
                title: t(g['title']),
                category: GoalCategory.values.byName(g['cat'] as String),
                description: Value(t(g['desc'])),
                targetDate: _day(g['date']),
                achieved: Value(g['done'] as bool? ?? false),
                createdAt: Value(_stamp(i, newestFirst: true)),
              ),
          ]);
          b.insertAll(db.milestones, [
            for (final g in _list('goals'))
              for (final (j, m) in (g['ms'] as List).cast<Json>().indexed)
                MilestonesCompanion.insert(
                  id: Value(m['id'] as String),
                  goalId: g['id'] as String,
                  title: t(m['t']),
                  done: Value(m['d'] as bool? ?? false),
                  sortOrder: Value(j),
                ),
          ]);
          b.insertAll(db.documents, [
            for (final (i, d) in _list('docs').indexed)
              DocumentsCompanion.insert(
                id: Value(d['id'] as String),
                title: t(d['title']),
                category: DocCategory.values.byName(d['cat'] as String),
                kind: DocKind.values.byName(d['kind'] as String),
                description: Value(t(d['desc'])),
                uploadedAt: Value(_day(d['date'])),
                sizeBytes: Value(_bytes('${d['size']}')),
                pages: Value(d['pages'] as int? ?? 1),
                createdAt: Value(_stamp(i, newestFirst: true)),
              ),
          ]);
          b.insertAll(db.inboxItems, [
            for (final (i, n) in _list('notifs').indexed)
              InboxItemsCompanion.insert(
                id: Value(n['id'] as String),
                icon: n['icon'] as String,
                tone: _tone(n['tone'] as String? ?? ''),
                title: t(n['title']),
                body: Value(t(n['sub'])),
                isRead: Value(n['read'] as bool? ?? false),
                route: Value(n['to'] as String? ?? ''),
                createdAt: Value(_stamp(i, newestFirst: true)),
              ),
          ]);
        });
      });

  /// Every bilingual value the seeder writes.
  List<_Slot> _slots() {
    final out = <_Slot>[];
    void add(TableInfo<Table, Object?> table, Json row, Map<String, String> fields, {String idKey = 'id'}) {
      for (final MapEntry(key: jsonKey, value: column) in fields.entries) {
        final v = row[jsonKey];
        if (v is List && v.length == 2) out.add(_Slot(table, row[idKey] as String, column, v[0] as String, v[1] as String));
      }
    }

    for (final x in _list('tx')) {
      add(db.transactions, x, {'title': 'title', 'desc': 'description', 'note': 'note'});
    }
    for (final x in _list('alloc')) {
      add(db.allocationCategories, x, {'name': 'name'});
    }
    for (final x in (data['salary'] as Json)['recs'] as List) {
      add(db.salaryRecords, x as Json, {'note': 'note'});
    }
    for (final x in _list('sav')) {
      add(db.savingsEntries, x, {'note': 'note'});
    }
    for (final x in _list('sgoals')) {
      add(db.savingsGoals, x, {'name': 'name'});
    }
    for (final x in _list('shops')) {
      add(db.shops, x, {'name': 'name'});
      for (final e in (x['ent'] as List).cast<Json>()) {
        add(db.shopEntries, e, {'item': 'item'});
      }
    }
    for (final x in _list('projects')) {
      add(db.projects, x, {'name': 'name', 'desc': 'description'});
    }
    for (final x in _list('tasks')) {
      add(db.tasks, x, {'title': 'title', 'desc': 'description', 'note': 'note'});
    }
    for (final x in _list('events')) {
      add(db.events, x, {'title': 'title', 'loc': 'location', 'desc': 'description'});
    }
    for (final x in _list('rems')) {
      add(db.reminders, x, {'title': 'title', 'desc': 'description'});
    }
    for (final x in _list('notes')) {
      add(db.notes, x, {'title': 'title', 'body': 'body'});
    }
    for (final x in _list('meals')) {
      add(db.meals, x, {'desc': 'description', 'note': 'note'});
    }
    for (final x in _list('goals')) {
      add(db.goals, x, {'title': 'title', 'desc': 'description'});
      for (final m in (x['ms'] as List).cast<Json>()) {
        add(db.milestones, m, {'t': 'title'});
      }
    }
    for (final x in _list('docs')) {
      add(db.documents, x, {'title': 'title', 'desc': 'description'});
    }
    for (final x in _list('notifs')) {
      add(db.inboxItems, x, {'title': 'title', 'sub': 'body'});
    }
    final bn = _l10n(AppLang.bn), en = _l10n(AppLang.en);
    for (final h in _list('habits')) {
      final key = h['name'] as String;
      out.add(_Slot(db.habits, h['id'] as String, 'name', _habitName(key, bn), _habitName(key, en)));
    }
    return out;
  }

  /// Swaps sample text from [from] to [to] where it is still exactly the seeded
  /// text; edited values are left alone. Returns the number of values changed.
  Future<int> relocalize(AppLang from, AppLang to) async {
    if (from == to) return 0;
    final slots = _slots();
    return db.transaction(() async {
      var changed = 0;
      for (final s in slots) {
        final oldText = from == AppLang.bn ? s.bn : s.en;
        final newText = to == AppLang.bn ? s.bn : s.en;
        if (oldText == newText) continue;
        changed += await db.customUpdate(
          'UPDATE "${s.table.actualTableName}" SET "${s.column}" = ?1 WHERE "id" = ?2 AND "${s.column}" = ?3',
          variables: [Variable.withString(newText), Variable.withString(s.id), Variable.withString(oldText)],
          updates: {s.table},
          updateKind: UpdateKind.update,
        );
      }
      return changed;
    });
  }
}
