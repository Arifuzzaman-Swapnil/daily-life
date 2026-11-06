// Keeps the device's pending notifications in step with the data: whenever
// reminders, events, the notification toggles or the language change (and
// whenever the app comes back to the foreground), the plan is rebuilt and
// handed to the scheduler. `app.dart` keeps [notificationSyncProvider] alive.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';
import '../../core/format/format_provider.dart';
import '../../core/notifications/notification_scheduler.dart';
import '../../core/prefs/app_settings.dart';
import '../../core/prefs/notification_prefs.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../calendar/calendar_providers.dart';
import 'notification_planner.dart';

/// The device scheduler; tests override it with a fake.
final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) => LocalNotificationScheduler(ref.watch(sharedPrefsProvider)));

final _activeRemindersProvider = StreamProvider<List<Reminder>>((ref) => ref.watch(remindersDaoProvider).watchActive());

/// The notifications that should be pending now; null until the data loads.
final notificationPlanProvider = Provider<List<PlannedNotification>?>((ref) {
  final reminders = ref.watch(_activeRemindersProvider).value;
  final events = ref.watch(eventsProvider).value;
  if (reminders == null || events == null) return null;
  final settings = ref.watch(settingsProvider);
  return planNotifications(
    now: ref.read(clockProvider)(),
    prefs: ref.watch(notificationPrefsProvider),
    reminders: reminders,
    events: events,
    t: lookupAppLocalizations(settings.locale),
    f: ref.watch(formatProvider),
  );
});

final notificationSyncProvider = Provider<void>((ref) {
  final scheduler = ref.watch(notificationSchedulerProvider);
  final router = ref.read(routerProvider);
  unawaited(scheduler.init((route) {
    if (Routes.tabs.contains(route)) {
      router.go(route);
    } else {
      router.push(route);
    }
  }));

  ref.listen<List<PlannedNotification>?>(notificationPlanProvider, (prev, next) {
    if (next == null || (prev != null && _same(prev, next))) return;
    final t = lookupAppLocalizations(ref.read(settingsProvider).locale);
    unawaited(scheduler.replaceAll(next, {NotifChannel.reminders: t.reminders, NotifChannel.health: t.health}));
  }, fireImmediately: true);

  // Back in the foreground: "now" has moved on, so plan again.
  final lifecycle = AppLifecycleListener(onResume: () => ref.invalidate(notificationPlanProvider));
  ref.onDispose(lifecycle.dispose);
});

bool _same(List<PlannedNotification> a, List<PlannedNotification> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
