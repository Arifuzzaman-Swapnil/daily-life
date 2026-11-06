// Fingerprint unlock through local_auth. Widget tests replace it with a fake.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

abstract class BiometricService {
  /// Whether the phone can unlock with a fingerprint (or face) that is set up.
  Future<bool> isAvailable();

  /// Shows the system prompt; true when the person was recognised. [title],
  /// [hint] and [cancel] are the prompt's texts in the app's language.
  Future<bool> authenticate({required String reason, required String title, required String hint, required String cancel});
}

final biometricServiceProvider = Provider<BiometricService>((ref) => DeviceBiometricService());

class DeviceBiometricService implements BiometricService {
  final _auth = LocalAuthentication();

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported() && (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on LocalAuthException catch (e) {
      debugPrint('Biometrics unavailable: ${e.code}');
      return false;
    } on PlatformException catch (e) {
      debugPrint('Biometrics unavailable: $e');
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason, required String title, required String hint, required String cancel}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        authMessages: [AndroidAuthMessages(signInTitle: title, signInHint: hint, cancelButton: cancel)],
      );
    } on LocalAuthException catch (e) {
      debugPrint('Fingerprint unlock failed: ${e.code}');
      return false;
    } on PlatformException catch (e) {
      debugPrint('Fingerprint unlock failed: $e');
      return false;
    }
  }
}
