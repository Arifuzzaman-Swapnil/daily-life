// Privacy settings: hide amounts, app lock, biometric unlock and the PIN.
// The PIN itself is never stored: only a salted SHA-256 hash of it.
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings.dart';

/// Length of the app-lock PIN.
const kPinLength = 4;

@immutable
class PrivacySettings {
  const PrivacySettings({this.hideAmounts = false, this.lock = false, this.biometric = false, this.hasPin = false});

  /// Every amount on screen shows as `৳ ••••`.
  final bool hideAmounts;

  /// The app asks for the PIN on launch and when it comes back.
  final bool lock;

  /// The lock screen also offers the fingerprint.
  final bool biometric;
  final bool hasPin;

  /// Whether the app locks: the lock is on and there is a PIN to unlock it with.
  bool get locks => lock && hasPin;

  PrivacySettings copyWith({bool? hideAmounts, bool? lock, bool? biometric, bool? hasPin}) => PrivacySettings(
        hideAmounts: hideAmounts ?? this.hideAmounts,
        lock: lock ?? this.lock,
        biometric: biometric ?? this.biometric,
        hasPin: hasPin ?? this.hasPin,
      );

  @override
  bool operator ==(Object other) =>
      other is PrivacySettings && other.hideAmounts == hideAmounts && other.lock == lock && other.biometric == biometric && other.hasPin == hasPin;

  @override
  int get hashCode => Object.hash(hideAmounts, lock, biometric, hasPin);
}

final privacyProvider = NotifierProvider<PrivacyController, PrivacySettings>(PrivacyController.new);

class PrivacyController extends Notifier<PrivacySettings> {
  @override
  PrivacySettings build() {
    final p = ref.watch(sharedPrefsProvider);
    return PrivacySettings(
      hideAmounts: p.getBool(PrefKeys.hideAmounts) ?? false,
      lock: p.getBool(PrefKeys.appLock) ?? false,
      biometric: p.getBool(PrefKeys.biometric) ?? false,
      hasPin: (p.getString(PrefKeys.pinHash) ?? '').isNotEmpty,
    );
  }

  Future<void> setHideAmounts(bool on) async {
    state = state.copyWith(hideAmounts: on);
    await ref.read(sharedPrefsProvider).setBool(PrefKeys.hideAmounts, on);
  }

  /// Turns the app lock on or off. It can only be on with a PIN.
  Future<void> setLock(bool on) async {
    if (on && !state.hasPin) throw StateError('App lock needs a PIN first');
    state = state.copyWith(lock: on);
    await ref.read(sharedPrefsProvider).setBool(PrefKeys.appLock, on);
  }

  Future<void> setBiometric(bool on) async {
    state = state.copyWith(biometric: on);
    await ref.read(sharedPrefsProvider).setBool(PrefKeys.biometric, on);
  }

  /// Stores a new [pin] (4 digits) as a hash with a fresh random salt.
  Future<void> setPin(String pin) async {
    assert(RegExp(r'^\d{4}$').hasMatch(pin));
    final salt = base64Url.encode(List<int>.generate(16, (_) => Random.secure().nextInt(256)));
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setString(PrefKeys.pinSalt, salt);
    await prefs.setString(PrefKeys.pinHash, hashPin(pin, salt));
    state = state.copyWith(hasPin: true);
  }

  /// Whether [pin] is the stored PIN.
  bool checkPin(String pin) {
    final prefs = ref.read(sharedPrefsProvider);
    final hash = prefs.getString(PrefKeys.pinHash);
    if (hash == null || hash.isEmpty) return false;
    return hashPin(pin, prefs.getString(PrefKeys.pinSalt) ?? '') == hash;
  }

  static String hashPin(String pin, String salt) => sha256.convert(utf8.encode('$salt:$pin')).toString();
}
