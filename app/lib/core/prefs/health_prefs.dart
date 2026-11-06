// Health preferences kept in shared_preferences. The water target is read by
// Home's water tile now and set from the Health screen (build step 6).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings.dart';

/// Daily water target in ml (prototype `wTarget`).
final waterTargetProvider = NotifierProvider<WaterTarget, int>(WaterTarget.new);

class WaterTarget extends Notifier<int> {
  static const defaultMl = 3000;
  static const minMl = 500;
  static const maxMl = 6000;

  @override
  int build() => (ref.watch(sharedPrefsProvider).getInt(PrefKeys.waterTarget) ?? defaultMl).clamp(minMl, maxMl);

  /// Clamped to 500–6000 ml.
  Future<void> set(int ml) async {
    state = ml.clamp(minMl, maxMl);
    await ref.read(sharedPrefsProvider).setInt(PrefKeys.waterTarget, state);
  }
}
