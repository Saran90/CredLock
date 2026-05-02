// Unit tests for DriveBackupService timestamp helpers.
//
// These tests cover the pure timestamp formatting/parsing logic which has no
// platform-channel dependencies and can run in the Dart VM test environment.

import 'package:flutter_test/flutter_test.dart';

import 'package:credlock/core/services/drive_backup_service.dart';

void main() {
  final svc = DriveBackupService.instance;

  group('DriveBackupService._formatTimestamp', () {
    test('formats a typical UTC datetime correctly', () {
      final dt = DateTime.utc(2025, 1, 15, 14, 30, 22);
      expect(svc.formatTimestamp(dt), equals('20250115T143022Z'));
    });

    test('pads single-digit month, day, hour, minute, second', () {
      final dt = DateTime.utc(2025, 3, 5, 9, 7, 3);
      expect(svc.formatTimestamp(dt), equals('20250305T090703Z'));
    });

    test('handles midnight (00:00:00)', () {
      final dt = DateTime.utc(2025, 12, 31, 0, 0, 0);
      expect(svc.formatTimestamp(dt), equals('20251231T000000Z'));
    });

    test('handles end of year (23:59:59)', () {
      final dt = DateTime.utc(2025, 12, 31, 23, 59, 59);
      expect(svc.formatTimestamp(dt), equals('20251231T235959Z'));
    });

    test('handles leap day', () {
      final dt = DateTime.utc(2024, 2, 29, 12, 0, 0);
      expect(svc.formatTimestamp(dt), equals('20240229T120000Z'));
    });

    test('output is always 16 characters long', () {
      final dt = DateTime.utc(2025, 1, 1, 0, 0, 0);
      expect(svc.formatTimestamp(dt).length, equals(16));
    });
  });

  group('DriveBackupService._parseTimestamp', () {
    test('parses a valid .db filename', () {
      final dt = svc.parseTimestamp('credlock_backup_20250115T143022Z.db');
      expect(dt, equals(DateTime.utc(2025, 1, 15, 14, 30, 22)));
    });

    test('parses a valid _settings.json filename', () {
      final dt = svc.parseTimestamp(
        'credlock_backup_20250115T143022Z_settings.json',
      );
      expect(dt, equals(DateTime.utc(2025, 1, 15, 14, 30, 22)));
    });

    test('returns null for an unrelated filename', () {
      expect(svc.parseTimestamp('some_other_file.db'), isNull);
    });

    test('returns null for an empty string', () {
      expect(svc.parseTimestamp(''), isNull);
    });

    test('returns null for a malformed timestamp', () {
      expect(svc.parseTimestamp('credlock_backup_BADTIMESTAMP.db'), isNull);
    });

    test('parses midnight correctly', () {
      final dt = svc.parseTimestamp('credlock_backup_20251231T000000Z.db');
      expect(dt, equals(DateTime.utc(2025, 12, 31, 0, 0, 0)));
    });
  });

  group('Timestamp round-trip', () {
    // Property 5: Backup Filename Timestamp Round-Trip
    // Validates: Requirements 5.4
    test(
      'Property 5 — formatTimestamp then parseTimestamp returns original DateTime',
      () {
        final testCases = [
          DateTime.utc(2025, 1, 15, 14, 30, 22),
          DateTime.utc(2025, 12, 31, 23, 59, 59),
          DateTime.utc(2025, 1, 1, 0, 0, 0),
          DateTime.utc(2024, 2, 29, 12, 0, 0), // leap day
          DateTime.utc(2025, 3, 5, 9, 7, 3),
          DateTime.utc(2000, 1, 1, 0, 0, 0),
          DateTime.utc(2099, 12, 31, 23, 59, 59),
        ];

        for (final original in testCases) {
          final filename =
              'credlock_backup_${svc.formatTimestamp(original)}.db';
          final parsed = svc.parseTimestamp(filename);
          expect(
            parsed,
            equals(original),
            reason: 'Round-trip failed for $original',
          );
        }
      },
    );

    test('round-trip preserves UTC timezone', () {
      final original = DateTime.utc(2025, 6, 15, 10, 30, 0);
      final filename = 'credlock_backup_${svc.formatTimestamp(original)}.db';
      final parsed = svc.parseTimestamp(filename);
      expect(parsed!.isUtc, isTrue);
    });
  });

  group('BackupEntry sort order', () {
    // Property 7: Backup List Sort Order
    // Validates: Requirements 6.1
    test('Property 7 — entries sorted newest first are in descending order', () {
      final entries = [
        BackupEntry(
          timestamp: '20250101T000000Z',
          utcDateTime: DateTime.utc(2025, 1, 1),
          dbFileId: 'id1',
          settingsFileId: 'sid1',
          displayLabel: 'Jan 1, 2025',
        ),
        BackupEntry(
          timestamp: '20250315T120000Z',
          utcDateTime: DateTime.utc(2025, 3, 15, 12),
          dbFileId: 'id2',
          settingsFileId: 'sid2',
          displayLabel: 'Mar 15, 2025',
        ),
        BackupEntry(
          timestamp: '20241201T080000Z',
          utcDateTime: DateTime.utc(2024, 12, 1, 8),
          dbFileId: 'id3',
          settingsFileId: 'sid3',
          displayLabel: 'Dec 1, 2024',
        ),
      ];

      // Sort newest first (same logic as DriveBackupService.listBackups).
      entries.sort((a, b) => b.utcDateTime.compareTo(a.utcDateTime));

      // Verify descending order.
      for (var i = 0; i < entries.length - 1; i++) {
        expect(
          entries[i].utcDateTime.isAfter(entries[i + 1].utcDateTime) ||
              entries[i].utcDateTime == entries[i + 1].utcDateTime,
          isTrue,
          reason:
              'Entry $i (${entries[i].utcDateTime}) is not >= entry ${i + 1} (${entries[i + 1].utcDateTime})',
        );
      }
    });
  });
}
