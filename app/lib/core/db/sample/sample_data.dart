// Sample data on and off: loads the bundled asset into [SampleSeeder].
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../format/dl_format.dart';
import '../../prefs/app_settings.dart';
import '../app_database.dart';
import '../db_providers.dart';
import 'sample_seeder.dart';

/// Build flag (`--dart-define=DL_SAMPLE_DATA=true`): a fresh install of this
/// build starts with the prototype's sample data. CI test builds set it; a real
/// release builds without it and starts empty.
const kSampleDataBuild = bool.fromEnvironment('DL_SAMPLE_DATA');

final sampleDataProvider = Provider<SampleDataService>((ref) => SampleDataService(ref.watch(appDatabaseProvider)));

/// Settings → "Show sample data": on while the sample data is loaded. Off
/// removes all records (categories and settings stay), which shows every
/// screen's empty state; on replaces the data with the sample data.
final sampleDataSwitchProvider = NotifierProvider<SampleDataSwitch, bool>(SampleDataSwitch.new);

class SampleDataSwitch extends Notifier<bool> {
  @override
  bool build() => ref.watch(sharedPrefsProvider).getBool(PrefKeys.sampleData) ?? false;

  Future<void> turnOn(AppLang lang) async {
    await ref.read(sampleDataProvider).load(lang);
    await ref.read(sharedPrefsProvider).setBool(PrefKeys.sampleData, true);
    state = true;
  }

  Future<void> turnOff() async {
    await ref.read(sampleDataProvider).clear();
    await ref.read(sharedPrefsProvider).setBool(PrefKeys.sampleData, false);
    state = false;
  }
}

class SampleDataService {
  /// [loadJson] reads the sample JSON; tests pass a file reader.
  SampleDataService(this.db, {Future<String> Function()? loadJson}) : _loadJson = loadJson ?? (() => rootBundle.loadString(asset));

  static const asset = 'assets/sample_data.json';

  final AppDatabase db;
  final Future<String> Function() _loadJson;

  Future<SampleSeeder> _seeder() async => SampleSeeder(db, SampleSeeder.parse(await _loadJson()));

  /// Replaces all data with the sample data in [lang].
  Future<void> load(AppLang lang) async => (await _seeder()).seed(lang);

  /// Removes all data (categories stay).
  Future<void> clear() => SampleSeeder.clearData(db);

  /// After a language switch: untouched sample text follows the new language.
  Future<void> relocalize(AppLang from, AppLang to) async => (await _seeder()).relocalize(from, to);

  /// For [kSampleDataBuild]: seeds once when the database is empty, unless the
  /// person turned sample data off. Returns whether it seeded.
  Future<bool> seedOnFirstRun(SharedPreferences prefs) async {
    if (prefs.getBool(PrefKeys.sampleData) == false) return false;
    if (await db.hasAnyData()) return false;
    final lang = AppLang.values.asNameMap()[prefs.getString(PrefKeys.lang)] ?? AppLang.bn;
    await load(lang);
    await prefs.setBool(PrefKeys.sampleData, true);
    return true;
  }
}
