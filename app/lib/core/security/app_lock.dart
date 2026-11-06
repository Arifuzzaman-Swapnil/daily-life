// App lock: whether the lock screen covers the app right now. It locks on
// launch and whenever the app is hidden (home button, app switcher, another
// app), when the lock is on and a PIN is set. Screens the app opens itself —
// the file picker, the share sheet, the fingerprint prompt — don't count:
// run them through [AppLockController.whileOutside].
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../prefs/privacy_prefs.dart';

/// True while the lock screen is showing.
final appLockProvider = NotifierProvider<AppLockController, bool>(AppLockController.new);

class AppLockController extends Notifier<bool> {
  int _outside = 0;

  @override
  bool build() {
    final listener = AppLifecycleListener(onHide: _onHide);
    ref.onDispose(listener.dispose);
    return ref.read(privacyProvider).locks;
  }

  void _onHide() {
    if (_outside > 0 || state || !ref.read(privacyProvider).locks) return;
    FocusManager.instance.primaryFocus?.unfocus();
    state = true;
  }

  /// The right PIN or fingerprint was given.
  void unlock() => state = false;

  /// Runs [action], which opens a system screen over the app; leaving the app
  /// for it doesn't lock.
  Future<T> whileOutside<T>(Future<T> Function() action) async {
    _outside++;
    try {
      return await action();
    } finally {
      _outside--;
    }
  }
}
