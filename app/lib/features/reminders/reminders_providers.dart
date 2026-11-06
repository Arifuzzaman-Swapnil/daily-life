// Riverpod access to reminders and the Reminders screen's tab (prototype
// `remTab`). Every value comes from a RemindersDao stream.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';
import '../finance/money_providers.dart';

enum RemTab { today, upcoming, completed }

final remTabProvider = NotifierProvider<RemTabController, RemTab>(RemTabController.new);

class RemTabController extends Notifier<RemTab> {
  @override
  RemTab build() => RemTab.today;

  void set(RemTab tab) => state = tab;
}

/// The open tab's reminders by date and time: Today includes overdue ones.
final remindersProvider = StreamProvider<List<Reminder>>((ref) {
  final dao = ref.watch(remindersDaoProvider);
  final today = todayFrom(ref);
  return switch (ref.watch(remTabProvider)) {
    RemTab.today => dao.watchToday(today),
    RemTab.upcoming => dao.watchUpcoming(today),
    RemTab.completed => dao.watchCompleted(),
  };
});

/// Tab counts.
final remCountsProvider = StreamProvider<({int today, int upcoming, int completed})>(
  (ref) => ref.watch(remindersDaoProvider).watchCounts(todayFrom(ref)),
);

/// Reminders due today or earlier that are on and not done (the More badge).
final remDueProvider = StreamProvider<int>(
  (ref) => ref.watch(remindersDaoProvider).watchToday(todayFrom(ref)).map((l) => l.where((r) => r.enabled).length),
);

/// One reminder; null once deleted.
final reminderProvider = StreamProvider.family<Reminder?, String>((ref, id) => ref.watch(remindersDaoProvider).watchReminder(id));
