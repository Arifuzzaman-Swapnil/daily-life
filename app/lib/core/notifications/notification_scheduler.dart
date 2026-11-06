// Real notifications on the device (flutter_local_notifications + timezone,
// Asia/Dhaka). The app hands over the whole plan each time it changes; the
// scheduler replaces every pending notification with it. Tests use a fake.
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

enum NotifRepeat { none, daily, weekly, monthly }

/// Reminders and events, or water and meals (separate Android channels, so
/// people can mute one kind in system settings).
enum NotifChannel { reminders, health }

/// One notification to show at [at] (Dhaka wall-clock time), optionally
/// repeating at the same time every day / week / month.
@immutable
class PlannedNotification {
  const PlannedNotification({
    required this.at,
    required this.title,
    required this.body,
    required this.route,
    this.repeat = NotifRepeat.none,
    this.channel = NotifChannel.reminders,
  });

  final DateTime at;
  final String title;
  final String body;

  /// Where tapping it goes (a router location).
  final String route;
  final NotifRepeat repeat;
  final NotifChannel channel;

  @override
  bool operator ==(Object other) =>
      other is PlannedNotification &&
      other.at == at &&
      other.title == title &&
      other.body == body &&
      other.route == route &&
      other.repeat == repeat &&
      other.channel == channel;

  @override
  int get hashCode => Object.hash(at, title, body, route, repeat, channel);

  @override
  String toString() => 'PlannedNotification($at ${repeat.name} "$title" → $route)';
}

abstract class NotificationScheduler {
  /// Sets the plugin up once. [onOpen] receives the route of a tapped
  /// notification, including the one that launched the app.
  Future<void> init(void Function(String route) onOpen);

  /// Replaces every pending notification with [plan]. [channelNames] are the
  /// localized channel names shown in system settings.
  Future<void> replaceAll(List<PlannedNotification> plan, Map<NotifChannel, String> channelNames);
}

class LocalNotificationScheduler implements NotificationScheduler {
  LocalNotificationScheduler(this._prefs);

  final SharedPreferences _prefs;
  final _plugin = FlutterLocalNotificationsPlugin();
  tz.Location? _dhaka;
  Future<void>? _ready;

  /// Only the newest plan matters; plans are applied one at a time.
  (List<PlannedNotification>, Map<NotifChannel, String>)? _next;
  Future<void> _queue = Future.value();

  /// Set once the notification permission has been asked for (Android 13+).
  static const _askedKey = 'pref.notif.asked';

  @override
  Future<void> init(void Function(String route) onOpen) => _ready ??= _init(onOpen);

  Future<void> _init(void Function(String route) onOpen) async {
    try {
      tzdata.initializeTimeZones();
      _dhaka = tz.getLocation('Asia/Dhaka');
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        onDidReceiveNotificationResponse: (r) {
          final route = r.payload;
          if (route != null && route.isNotEmpty) onOpen(route);
        },
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final route = launch?.notificationResponse?.payload;
      if ((launch?.didNotificationLaunchApp ?? false) && route != null && route.isNotEmpty) onOpen(route);
    } catch (e, st) {
      debugPrint('Notifications are unavailable: $e\n$st');
    }
  }

  @override
  Future<void> replaceAll(List<PlannedNotification> plan, Map<NotifChannel, String> channelNames) {
    _next = (plan, channelNames);
    return _queue = _queue.then((_) async {
      final next = _next;
      if (next == null) return;
      _next = null;
      try {
        await _apply(next.$1, next.$2);
      } catch (e, st) {
        debugPrint('Notifications were not scheduled: $e\n$st');
      }
    });
  }

  Future<void> _apply(List<PlannedNotification> plan, Map<NotifChannel, String> channelNames) async {
    await _ready;
    final dhaka = _dhaka;
    if (dhaka == null) return;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (plan.isNotEmpty && _prefs.getBool(_askedKey) != true) {
      await _prefs.setBool(_askedKey, true);
      await android?.requestNotificationsPermission();
    }
    // Exact timing when Android allows it (Android 14+ asks the person in
    // system settings); otherwise Android may deliver a few minutes late.
    final exact = await android?.canScheduleExactNotifications() ?? false;
    await _plugin.cancelAllPendingNotifications();
    for (final (i, n) in plan.indexed) {
      await _plugin.zonedSchedule(
        id: i + 1,
        scheduledDate: tz.TZDateTime(dhaka, n.at.year, n.at.month, n.at.day, n.at.hour, n.at.minute),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            n.channel.name,
            channelNames[n.channel] ?? n.channel.name,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        title: n.title,
        body: n.body,
        payload: n.route,
        matchDateTimeComponents: switch (n.repeat) {
          NotifRepeat.none => null,
          NotifRepeat.daily => DateTimeComponents.time,
          NotifRepeat.weekly => DateTimeComponents.dayOfWeekAndTime,
          NotifRepeat.monthly => DateTimeComponents.dayOfMonthAndTime,
        },
      );
    }
  }
}
