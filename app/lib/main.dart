import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/db/db_providers.dart';
import 'core/db/sample/sample_data.dart';
import 'core/prefs/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final prefs = await SharedPreferences.getInstance();
  final db = openAppDatabase();
  if (kSampleDataBuild) {
    try {
      await SampleDataService(db).seedOnFirstRun(prefs);
    } catch (e, st) {
      debugPrint('Sample data was not loaded: $e\n$st');
    }
  }
  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: const DailyLifeApp(),
    ),
  );
}
