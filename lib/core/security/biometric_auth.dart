import 'package:local_auth/local_auth.dart';

/// Provides a narrow interface over the platform's biometric subsystem
/// (Face ID / Touch ID on iOS, BiometricPrompt on Android).
///
/// Every public method is fault-tolerant: hardware failures, user cancellation,
/// and missing enrollment all resolve to safe boolean/empty-list values rather
/// than propagating exceptions to the UI layer.
class BiometricAuth {
  BiometricAuth._();

  static final BiometricAuth instance = BiometricAuth._();

  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Whether the device hardware supports any form of biometric authentication.
  /// Returns `false` on simulators or devices without a biometric sensor.
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } on Exception {
      return false;
    }
  }

  /// Whether the user has enrolled at least one biometric credential on this
  /// device. A `true` from [isDeviceSupported] with a `false` here means the
  /// hardware exists but the user hasn't set up Face/Fingerprint yet.
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } on Exception {
      return false;
    }
  }

  /// Enumerates the biometric modalities available on this device
  /// (e.g. fingerprint, face, iris). Returns an empty list on failure.
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on Exception {
      return <BiometricType>[];
    }
  }

  /// Triggers the OS-level biometric prompt with [reason] displayed to the user.
  ///
  /// Uses `biometricOnly: true` to prevent fallback to device PIN/passcode,
  /// ensuring the authentication gate remains strictly biometric.
  /// `stickyAuth: true` keeps the auth session alive across app lifecycle
  /// interruptions (e.g. incoming phone call) so the user isn't re-prompted.
  Future<bool> authenticate({
    String reason = 'Authenticate to access Trulana',
  }) async {
    try {
      final bool result = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      return result;
    } on Exception {
      return false;
    }
  }
}
