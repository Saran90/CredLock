import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AutofillService {
  static const platform = MethodChannel('com.credlock.credlock/autofill');

  /// Enable autofill for the app
  static Future<bool> enableAutofill() async {
    try {
      final result = await platform.invokeMethod<bool>('enableAutofill');
      return result ?? false;
    } catch (e) {
      debugPrint('Error enabling autofill: $e');
      return false;
    }
  }

  /// Disable autofill for the app
  static Future<bool> disableAutofill() async {
    try {
      final result = await platform.invokeMethod<bool>('disableAutofill');
      return result ?? false;
    } catch (e) {
      debugPrint('Error disabling autofill: $e');
      return false;
    }
  }

  /// Check if autofill is enabled
  static Future<bool> isAutofillEnabled() async {
    try {
      final result = await platform.invokeMethod<bool>('isAutofillEnabled');
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking autofill status: $e');
      return false;
    }
  }

  /// Provide autofill data for a specific package
  static Future<bool> provideAutofillData({
    required String packageName,
    required String username,
    required String password,
  }) async {
    try {
      final result = await platform.invokeMethod<bool>('provideAutofillData', {
        'packageName': packageName,
        'username': username,
        'password': password,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('Error providing autofill data: $e');
      return false;
    }
  }
}
