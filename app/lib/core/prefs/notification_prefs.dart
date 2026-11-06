// Notification toggles (prototype `nset`), kept in shared_preferences. Settings
// shows all five; Health's water and meal switches are the same values.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings.dart';

enum NotifKind {
  /// Reminders outside the Office category.
  general,

  /// Every 2 hours, 8 AM–10 PM.
  water,

  /// At the usual meal times.
  meal,

  /// Office reminders.
  office,

  /// Event reminders.
  calendar,
}

@immutable
class NotificationPrefs {
  const NotificationPrefs(this.on);

  /// The prototype's defaults: everything on except meals.
  static const defaults = NotificationPrefs({
    NotifKind.general: true,
    NotifKind.water: true,
    NotifKind.meal: false,
    NotifKind.office: true,
    NotifKind.calendar: true,
  });

  final Map<NotifKind, bool> on;

  bool operator [](NotifKind k) => on[k] ?? defaults.on[k]!;

  @override
  bool operator ==(Object other) => other is NotificationPrefs && NotifKind.values.every((k) => this[k] == other[k]);

  @override
  int get hashCode => Object.hashAll([for (final k in NotifKind.values) this[k]]);
}

/// `pref.notif.<kind>`.
String notifPrefKey(NotifKind k) => 'pref.notif.${k.name}';

final notificationPrefsProvider = NotifierProvider<NotificationPrefsController, NotificationPrefs>(NotificationPrefsController.new);

class NotificationPrefsController extends Notifier<NotificationPrefs> {
  @override
  NotificationPrefs build() {
    final sp = ref.watch(sharedPrefsProvider);
    return NotificationPrefs({for (final k in NotifKind.values) k: sp.getBool(notifPrefKey(k)) ?? NotificationPrefs.defaults[k]});
  }

  Future<void> set(NotifKind k, bool value) async {
    state = NotificationPrefs({...state.on, k: value});
    await ref.read(sharedPrefsProvider).setBool(notifPrefKey(k), value);
  }
}
