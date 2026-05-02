import 'dart:convert';
import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import '../../data/db/database_helper.dart';
import '../../data/repositories/reminder_settings_repository.dart';
import 'auth_service.dart';

/// A single backup bundle stored in Google Drive appDataFolder.
class BackupEntry {
  final String timestamp; // e.g. "20250115T143022Z"
  final DateTime utcDateTime;
  final String dbFileId;
  final String settingsFileId;
  final String displayLabel; // human-readable local date/time

  const BackupEntry({
    required this.timestamp,
    required this.utcDateTime,
    required this.dbFileId,
    required this.settingsFileId,
    required this.displayLabel,
  });
}

/// Handles Google Drive backup and restore for the CredLock vault.
class DriveBackupService {
  DriveBackupService._();
  static final DriveBackupService instance = DriveBackupService._();

  // ── Timestamp helpers ──────────────────────────────────────────────────────

  /// Formats a UTC [DateTime] to `YYYYMMDDTHHmmssZ`.
  String formatTimestamp(DateTime utc) {
    final year = utc.year.toString().padLeft(4, '0');
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    final hour = utc.hour.toString().padLeft(2, '0');
    final minute = utc.minute.toString().padLeft(2, '0');
    final second = utc.second.toString().padLeft(2, '0');
    return '$year$month${day}T$hour$minute${second}Z';
  }

  /// Parses a UTC [DateTime] from a backup filename.
  /// Returns null if the filename does not contain a valid timestamp.
  DateTime? parseTimestamp(String filename) {
    // Pattern: credlock_backup_YYYYMMDDTHHmmssZ
    final re = RegExp(r'credlock_backup_(\d{8}T\d{6}Z)');
    final match = re.firstMatch(filename);
    if (match == null) return null;
    final ts = match.group(1)!;
    try {
      final year = int.parse(ts.substring(0, 4));
      final month = int.parse(ts.substring(4, 6));
      final day = int.parse(ts.substring(6, 8));
      final hour = int.parse(ts.substring(9, 11));
      final minute = int.parse(ts.substring(11, 13));
      final second = int.parse(ts.substring(13, 15));
      return DateTime.utc(year, month, day, hour, minute, second);
    } catch (_) {
      return null;
    }
  }

  String _displayLabel(DateTime utc) {
    final local = utc.toLocal();
    final months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = local.hour > 12
        ? local.hour - 12
        : (local.hour == 0 ? 12 : local.hour);
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    final min = local.minute.toString().padLeft(2, '0');
    return '${months[local.month]} ${local.day}, ${local.year}  $hour:$min $ampm';
  }

  // ── Drive API helper ───────────────────────────────────────────────────────

  Future<drive.DriveApi> _driveApi() async {
    final client = await AuthService.instance.getAuthClient();
    return drive.DriveApi(client);
  }

  // ── Backup ─────────────────────────────────────────────────────────────────

  /// Backs up the encrypted DB and reminder settings to Google Drive appDataFolder.
  /// Returns the UTC timestamp string used in the filenames.
  Future<String> backup() async {
    final api = await _driveApi();
    final timestamp = formatTimestamp(DateTime.now().toUtc());

    // 1. Close DB, read file bytes.
    await DatabaseHelper.instance.close();
    final dbPath = await DatabaseHelper.instance.getDatabasePath();
    final dbBytes = await File(dbPath).readAsBytes();

    // 2. Export settings snapshot.
    final settingsMap = await SharedPrefsReminderSettingsRepository.instance
        .exportToMap();
    final settingsBytes = utf8.encode(jsonEncode(settingsMap));

    // 3. Upload DB file.
    final dbFile = drive.File()
      ..name = 'credlock_backup_$timestamp.db'
      ..parents = ['appDataFolder'];
    final dbMedia = drive.Media(
      Stream.value(dbBytes),
      dbBytes.length,
      contentType: 'application/octet-stream',
    );
    await api.files.create(dbFile, uploadMedia: dbMedia);

    // 4. Upload settings JSON file.
    final settingsFile = drive.File()
      ..name = 'credlock_backup_${timestamp}_settings.json'
      ..parents = ['appDataFolder'];
    final settingsMedia = drive.Media(
      Stream.value(settingsBytes),
      settingsBytes.length,
      contentType: 'application/json',
    );
    await api.files.create(settingsFile, uploadMedia: settingsMedia);

    return timestamp;
  }

  // ── List backups ───────────────────────────────────────────────────────────

  /// Lists available backup bundles from Google Drive, sorted newest first.
  Future<List<BackupEntry>> listBackups() async {
    final api = await _driveApi();

    // List all .db backup files.
    final dbResult = await api.files.list(
      q: "name contains 'credlock_backup_' and name contains '.db'",
      spaces: 'appDataFolder',
      $fields: 'files(id,name)',
    );

    final dbFiles = dbResult.files ?? [];
    if (dbFiles.isEmpty) return [];

    // List all settings JSON files.
    final settingsResult = await api.files.list(
      q: "name contains 'credlock_backup_' and name contains '_settings.json'",
      spaces: 'appDataFolder',
      $fields: 'files(id,name)',
    );
    final settingsFiles = settingsResult.files ?? [];

    // Build a map of timestamp → settings file ID.
    final settingsMap = <String, String>{};
    for (final f in settingsFiles) {
      final ts = parseTimestamp(f.name ?? '');
      if (ts != null && f.id != null) {
        settingsMap[formatTimestamp(ts)] = f.id!;
      }
    }

    // Pair each .db file with its settings file.
    final entries = <BackupEntry>[];
    for (final f in dbFiles) {
      final utc = parseTimestamp(f.name ?? '');
      if (utc == null || f.id == null) continue;
      final ts = formatTimestamp(utc);
      final settingsId = settingsMap[ts];
      if (settingsId == null) continue;
      entries.add(
        BackupEntry(
          timestamp: ts,
          utcDateTime: utc,
          dbFileId: f.id!,
          settingsFileId: settingsId,
          displayLabel: _displayLabel(utc),
        ),
      );
    }

    // Sort newest first.
    entries.sort((a, b) => b.utcDateTime.compareTo(a.utcDateTime));
    return entries;
  }

  // ── Restore ────────────────────────────────────────────────────────────────

  /// Downloads and applies the selected backup.
  /// Throws on any error — on-device state is unchanged if error occurs before
  /// file replacement.
  Future<void> restore(BackupEntry entry) async {
    final api = await _driveApi();

    // 1. Download DB bytes.
    final dbMedia =
        await api.files.get(
              entry.dbFileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;
    final dbBytes = await _collectBytes(dbMedia.stream);

    // 2. Download settings JSON bytes.
    final settingsMedia =
        await api.files.get(
              entry.settingsFileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;
    final settingsBytes = await _collectBytes(settingsMedia.stream);

    // 3. Close DB and replace file.
    await DatabaseHelper.instance.close();
    final dbPath = await DatabaseHelper.instance.getDatabasePath();
    await File(dbPath).writeAsBytes(dbBytes, flush: true);

    // 4. Restore settings.
    final settingsMap =
        jsonDecode(utf8.decode(settingsBytes)) as Map<String, dynamic>;
    await SharedPrefsReminderSettingsRepository.instance.importFromMap(
      settingsMap,
    );
  }

  Future<List<int>> _collectBytes(Stream<List<int>> stream) async {
    final chunks = <int>[];
    await for (final chunk in stream) {
      chunks.addAll(chunk);
    }
    return chunks;
  }
}
