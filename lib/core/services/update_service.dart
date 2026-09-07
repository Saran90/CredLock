import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The result of a version check.
enum UpdateStatus {
  /// App is up to date — nothing to show.
  upToDate,

  /// A newer version is available but the user can continue using the app.
  softUpdate,

  /// The running version is below the minimum required — user must update.
  forceUpdate,
}

/// Holds the parsed data from the remote update_config.json.
class UpdateInfo {
  final UpdateStatus status;
  final String latestVersion;
  final String minRequiredVersion;
  final String releaseNotes;
  final String updateUrl;
  final String currentVersion;

  const UpdateInfo({
    required this.status,
    required this.latestVersion,
    required this.minRequiredVersion,
    required this.releaseNotes,
    required this.updateUrl,
    required this.currentVersion,
  });
}

/// Fetches the remote version config and determines whether a force or soft
/// update is needed based on the running app version.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  /// Set by SplashScreen after a successful check. HomeScreen reads this once
  /// on first build to decide whether to show the soft-update banner.
  /// Cleared after HomeScreen consumes it.
  static UpdateInfo? pendingInfo;

  /// Raw URL of update_config.json hosted on GitHub.
  static const String _configUrl =
      'https://raw.githubusercontent.com/Saran90/CredLock/master/update_config.json';

  /// SharedPreferences key for remembering which version the user last
  /// dismissed the soft-update banner for.
  static const String _prefKeyDismissedVersion = 'update_dismissed_version';

  /// Fetches the remote config and returns an [UpdateInfo].
  /// Returns null if the check fails (network error, parse error, etc.) —
  /// the caller should treat null as "up to date" and continue normally.
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await http
          .get(Uri.parse(_configUrl))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final latestVersion = json['latest_version'] as String? ?? '';
      final minRequiredVersion = json['min_required_version'] as String? ?? '';
      final releaseNotes = json['release_notes'] as String? ?? '';
      final updateUrl = json['update_url'] as String? ?? '';

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final status = _determineStatus(
        current: currentVersion,
        latest: latestVersion,
        minRequired: minRequiredVersion,
      );

      return UpdateInfo(
        status: status,
        latestVersion: latestVersion,
        minRequiredVersion: minRequiredVersion,
        releaseNotes: releaseNotes,
        updateUrl: updateUrl,
        currentVersion: currentVersion,
      );
    } catch (e) {
      debugPrint('UpdateService: check failed — $e');
      return null;
    }
  }

  /// Returns true if the user has already dismissed the soft-update banner
  /// for the given [latestVersion].
  Future<bool> isDismissed(String latestVersion) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyDismissedVersion) == latestVersion;
  }

  /// Stores [latestVersion] so the soft-update banner won't reappear until
  /// the remote config bumps the version again.
  Future<void> dismissSoftUpdate(String latestVersion) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyDismissedVersion, latestVersion);
  }

  // ── Version comparison ────────────────────────────────────────────────────

  UpdateStatus _determineStatus({
    required String current,
    required String latest,
    required String minRequired,
  }) {
    if (_compareVersions(current, minRequired) < 0) {
      return UpdateStatus.forceUpdate;
    }
    if (_compareVersions(current, latest) < 0) {
      return UpdateStatus.softUpdate;
    }
    return UpdateStatus.upToDate;
  }

  /// Compares two semantic version strings (major.minor.patch).
  /// Returns negative if `a` is less than `b`, zero if equal, positive if greater.
  int _compareVersions(String a, String b) {
    final aParts = _parseParts(a);
    final bParts = _parseParts(b);
    for (int i = 0; i < 3; i++) {
      final diff = aParts[i] - bParts[i];
      if (diff != 0) return diff;
    }
    return 0;
  }

  List<int> _parseParts(String version) {
    final parts = version.trim().split('.').map((p) {
      return int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }).toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts;
  }
}
