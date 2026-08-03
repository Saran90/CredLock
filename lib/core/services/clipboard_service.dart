import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles clipboard copy with automatic timed clearing.
/// The clear timeout is configurable and persisted via SharedPreferences.
class ClipboardService {
  ClipboardService._();
  static final ClipboardService instance = ClipboardService._();

  static const _prefKey = 'clipboard_clear_timeout_seconds';

  /// Sentinel value meaning auto-clear is disabled.
  static const int disabled = 0;

  /// Available timeout options exposed to the settings UI.
  static const List<int> timeoutOptions = [15, 30, 60, disabled];

  Timer? _clearTimer;
  int _timeoutSeconds = 30;

  /// Load persisted setting. Call once at app startup (or lazily on first use).
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _timeoutSeconds = prefs.getInt(_prefKey) ?? 30;
  }

  int get timeoutSeconds => _timeoutSeconds;

  Future<void> setTimeoutSeconds(int seconds) async {
    _timeoutSeconds = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, seconds);
  }

  /// Copies [value] to the clipboard.
  /// If auto-clear is enabled, shows a [SnackBar] with the countdown and
  /// schedules the clipboard wipe. Cancels any pending previous timer first.
  ///
  /// Pass the current [ScaffoldMessengerState] via [messengerKey] so callers
  /// don't need to pass BuildContext to the service.
  void copyWithAutoClear({
    required String value,
    required String label,
    required ScaffoldMessengerState messenger,
  }) {
    if (value.isEmpty) return;

    // Cancel any in-flight timer from a previous copy.
    _clearTimer?.cancel();

    Clipboard.setData(ClipboardData(text: value));

    if (_timeoutSeconds == disabled) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('$label copied'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFFFF8C00).withValues(alpha: 0.9),
        ),
      );
      return;
    }

    // Show a persistent snackbar that counts down.
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('$label copied — clears in ${_timeoutSeconds}s'),
        duration: Duration(seconds: _timeoutSeconds),
        backgroundColor: const Color(0xFFFF8C00).withValues(alpha: 0.9),
        action: SnackBarAction(
          label: 'Clear now',
          textColor: Colors.white,
          onPressed: () {
            _clearTimer?.cancel();
            Clipboard.setData(const ClipboardData(text: ''));
          },
        ),
      ),
    );

    _clearTimer = Timer(Duration(seconds: _timeoutSeconds), () {
      Clipboard.setData(const ClipboardData(text: ''));
    });
  }

  /// Cancel any pending clipboard clear timer (e.g. on sign-out).
  void cancelPendingClear() {
    _clearTimer?.cancel();
    _clearTimer = null;
  }
}
