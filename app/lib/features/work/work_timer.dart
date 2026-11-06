// The work timer's rules (brief + prototype `tStart` … `tComplete`), applied to
// the single persisted TimerSessions row so the timer survives restarts:
// - start → running; starting on a not-started task moves it to in progress
// - pause keeps the accumulated time; resume carries on from it
// - stop logs max(1, round(minutes)) to the task and remembers it ("X logged")
// - "Mark complete" sets the task done and resets the timer
// - the task can't change while the timer is running or paused
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/daos/work_dao.dart';
import '../../core/db/db_providers.dart';
import '../../core/format/format_provider.dart';

extension TimerSessionX on TimerSession {
  bool get busy => state == TimerState.running || state == TimerState.paused;

  /// Elapsed time at [now]: the accumulated time plus the current run.
  int elapsedMs(DateTime now) {
    final run = state == TimerState.running && startedAt != null ? now.difference(startedAt!).inMilliseconds : 0;
    return accumulatedMs + math.max(0, run);
  }
}

final workTimerProvider = Provider<WorkTimer>(WorkTimer.new);

class WorkTimer {
  WorkTimer(this._ref);

  final Ref _ref;

  WorkDao get _dao => _ref.read(workDaoProvider);
  DateTime get _now => _ref.read(clockProvider)();
  Future<T> _tx<T>(Future<T> Function() body) => _ref.read(appDatabaseProvider).transaction(body);

  /// Chooses the task to time. Ignored while the timer is running or paused.
  Future<void> pickTask(String taskId) => _tx(() async {
        final s = await _dao.timer();
        if (s.busy) return;
        await _dao.saveTimer(TimerSessionsCompanion(
          taskId: Value(taskId),
          state: const Value(TimerState.idle),
          accumulatedMs: const Value(0),
          startedAt: const Value(null),
        ));
      });

  Future<void> start() => _tx(() async {
        final s = await _dao.timer();
        await _dao.saveTimer(TimerSessionsCompanion(
          state: const Value(TimerState.running),
          accumulatedMs: const Value(0),
          startedAt: Value(_now),
          lastLoggedMinutes: const Value(0),
        ));
        final id = s.taskId;
        if (id == null) return;
        final task = await _dao.taskById(id);
        if (task != null && task.status == TaskStatus.todo) await _dao.setStatus(id, TaskStatus.inProgress);
      });

  Future<void> pause() => _tx(() async {
        final s = await _dao.timer();
        if (s.state != TimerState.running) return;
        await _dao.saveTimer(TimerSessionsCompanion(
          state: const Value(TimerState.paused),
          accumulatedMs: Value(s.elapsedMs(_now)),
          startedAt: const Value(null),
        ));
      });

  Future<void> resume() => _tx(() async {
        final s = await _dao.timer();
        if (s.state != TimerState.paused) return;
        await _dao.saveTimer(TimerSessionsCompanion(state: const Value(TimerState.running), startedAt: Value(_now)));
      });

  /// Stops and logs the time to the task; returns the minutes logged.
  Future<int> stop() => _tx(() async {
        final s = await _dao.timer();
        final ms = s.elapsedMs(_now);
        final minutes = math.max(1, (ms / 60000).round());
        await _dao.saveTimer(TimerSessionsCompanion(
          state: const Value(TimerState.stopped),
          accumulatedMs: Value(ms),
          startedAt: const Value(null),
          lastLoggedMinutes: Value(minutes),
        ));
        final id = s.taskId;
        if (id != null) await _dao.addSpentMinutes(id, minutes);
        return minutes;
      });

  /// "Mark complete" after a stop: the task is done and the timer resets.
  Future<void> complete() => _tx(() async {
        final s = await _dao.timer();
        final id = s.taskId;
        if (id != null) await _dao.setStatus(id, TaskStatus.done);
        await _dao.saveTimer(const TimerSessionsCompanion(state: Value(TimerState.idle), accumulatedMs: Value(0)));
      });
}
