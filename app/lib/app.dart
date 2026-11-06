import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/db/sample/sample_data.dart';
import 'core/prefs/app_settings.dart';
import 'core/theme/dl_theme.dart';
import 'features/notifications/notification_sync.dart';
import 'l10n/app_localizations.dart';
import 'router.dart';

class DailyLifeApp extends ConsumerWidget {
  const DailyLifeApp({super.key});

  static final _light = DLTheme.light();
  static final _dark = DLTheme.dark();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      routerConfig: router,
      builder: (context, child) {
        // Status bar icons follow the theme on screens without an AppBar.
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
          ),
          child: child!,
        );
      },
    );
  }
}
