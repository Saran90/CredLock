import 'dart:convert';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';

class AppMatch {
  final String appName;
  final String packageName;
  final String? iconBase64;

  const AppMatch({
    required this.appName,
    required this.packageName,
    this.iconBase64,
  });
}

class AppLookupService {
  AppLookupService._();
  static final AppLookupService instance = AppLookupService._();

  List<AppInfo>? _cache;

  /// Load all installed non-system apps with icons once and cache.
  Future<void> preload() async {
    if (_cache != null) return;
    _cache = await InstalledApps.getInstalledApps(
      true,
      true,
      '',
      BuiltWith.native_or_others,
    );
    _cache!.sort((a, b) => a.name.compareTo(b.name));
  }

  /// Fuzzy-search installed apps by name. Returns up to 5 matches.
  Future<List<AppMatch>> search(String query) async {
    if (query.trim().isEmpty) return [];
    await preload();
    final q = query.toLowerCase();
    final results = (_cache ?? [])
        .where((a) => a.name.toLowerCase().contains(q))
        .take(5)
        .map(
          (a) => AppMatch(
            appName: a.name,
            packageName: a.packageName,
            iconBase64: a.icon != null ? base64Encode(a.icon!) : null,
          ),
        )
        .toList();
    // Prefix matches first
    results.sort((a, b) {
      final aStarts = a.appName.toLowerCase().startsWith(q) ? 0 : 1;
      final bStarts = b.appName.toLowerCase().startsWith(q) ? 0 : 1;
      return aStarts.compareTo(bStarts);
    });
    return results;
  }
}
