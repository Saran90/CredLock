import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages biometric / device-credential authentication and the user's
/// preference for whether it is enabled.
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  static const _prefKey = 'biometric_auth_enabled';

  final _auth = LocalAuthentication();

  // ── Capability checks ──────────────────────────────────────────────────────

  /// Returns true if the device supports biometric or device-credential auth
  /// (fingerprint, face, PIN, pattern, password).
  Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck || isDeviceSupported;
    } catch (_) {
      return false;
    }
  }

  /// Returns true if at least one biometric is enrolled on the device.
  /// Falls back to device credentials (PIN/pattern/password) if no biometrics
  /// are enrolled but the device is secured.
  Future<bool> hasBiometricOrDeviceCredential() async {
    try {
      final enrolled = await _auth.getAvailableBiometrics();
      if (enrolled.isNotEmpty) return true;
      // No biometrics enrolled — check if device credential is available
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  // ── User preference ────────────────────────────────────────────────────────

  /// Whether the user has enabled biometric auth in settings.
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  /// Persist the user's preference.
  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  // ── Authentication ─────────────────────────────────────────────────────────

  /// Prompts the user to authenticate.
  ///
  /// Uses biometrics if available; falls back to device PIN/pattern/password
  /// automatically via [BiometricType] fallback in local_auth.
  ///
  /// Returns `true` on success, `false` on failure / cancellation.
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Authenticate to access your vault',
        options: const AuthenticationOptions(
          biometricOnly: false, // allow PIN/pattern/password fallback
          stickyAuth: true,     // keep prompt alive if app goes to background
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
