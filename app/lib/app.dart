import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/db/sample/sample_data.dart';
import 'core/prefs/app_settings.dart';
import 'core/security/app_lock.dart';
import 'core/theme/dl_theme.dart';
import 'features/notifications/notification_sync.dart';
import 'features/privacy/lock_screen.dart';
import 'l10n/app_localizations.dart';
import 'router.dart';

class DailyLifeApp extends ConsumerStatefulWidget {
  const DailyLifeApp({super.key});

  @override
  ConsumerState<DailyLifeApp> createState() => _DailyLifeAppState();
}

class _DailyLifeAppState extends ConsumerState<DailyLifeApp> {
  static final _light = DLTheme.light();
  static final _dark = DLTheme.dark();

  /// While the lock screen shows, system back leaves the app instead of
  /// popping the pages hidden under it.
  late final _back = _LockAwareBackButtonDispatcher(() => ref.read(appLockProvider));

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);
    // Device notifications follow reminders, events and the toggles.
    ref.watch(notificationSyncProvider);
    // Sample data follows the language, like the prototype (edited text stays).
    ref.listen(settingsProvider.select((s) => s.lang), (prev, next) {
      if (prev == null || prev == next) return;
      if (ref.read(sharedPrefsProvider).getBool(PrefKeys.sampleData) != true) return;
      unawaited(ref.read(sampleDataProvider).relocalize(prev, next));
    });
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: _light,
      darkTheme: _dark,
      themeMode: settings.themeMode,
      themeAnimationDuration: const Duration(milliseconds: 250),
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerDelegate: router.routerDelegate,
      routeInformationParser: router.routeInformationParser,
      routeInformationProvider: router.routeInformationProvider,
      backButtonDispatcher: _back,
      builder: (context, child) {
        // Status bar icons follow the theme on screens without an AppBar.
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
          ),
          child: AppLockGate(child: child!),
        );
      },
    );
  }
}

class _LockAwareBackButtonDispatcher extends RootBackButtonDispatcher {
  _LockAwareBackButtonDispatcher(this._locked);

  final bool Function() _locked;

  @override
  Future<bool> didPopRoute() => _locked() ? Future<bool>.value(false) : super.didPopRoute();
}
