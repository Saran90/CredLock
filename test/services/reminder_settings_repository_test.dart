// Unit tests for SharedPrefsReminderSettingsRepository export/import.
//
// Uses SharedPreferences.setMockInitialValues to avoid platform-channel
// dependencies in the test environment.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:credlock/data/repositories/reminder_settings_repository.dart';

void main() {
  setUp(() {
    // Reset SharedPreferences to a clean state before each test.
    SharedPreferences.setMockInitialValues({});
  });

  final repo = SharedPrefsReminderSettingsRepository.instance;

  group('exportToMap', () {
    test('returns null values when nothing has been set', () async {
      final map = await repo.exportToMap();
      expect(map['reminder_enabled'], isNull);
      expect(map['reminder_frequency'], isNull);
      expect(map['reminder_last_notified_date'], isNull);
    });

    test('returns set values correctly', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('reminder_enabled', true);
      await prefs.setString('reminder_frequency', 'oneMonth');
      await prefs.setString(
        'reminder_last_notified_date',
        '2025-01-10T00:00:00.000',
      );

      final map = await repo.exportToMap();
      expect(map['reminder_enabled'], isTrue);
      expect(map['reminder_frequency'], equals('oneMonth'));
      expect(
        map['reminder_last_notified_date'],
        equals('2025-01-10T00:00:00.000'),
      );
    });
  });

  group('importFromMap', () {
    test('imports all three fields correctly', () async {
      final input = {
        'reminder_enabled': false,
        'reminder_frequency': 'twoWeeks',
        'reminder_last_notified_date': '2025-06-01T00:00:00.000',
      };
      await repo.importFromMap(input);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('reminder_enabled'), isFalse);
      expect(prefs.getString('reminder_frequency'), equals('twoWeeks'));
      expect(
        prefs.getString('reminder_last_notified_date'),
        equals('2025-06-01T00:00:00.000'),
      );
    });

    test('removes reminder_last_notified_date when null', () async {
      // First set a value.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'reminder_last_notified_date',
        '2025-01-01T00:00:00.000',
      );

      // Import with null last notified date.
      await repo.importFromMap({
        'reminder_enabled': true,
        'reminder_frequency': 'oneMonth',
        'reminder_last_notified_date': null,
      });

      expect(prefs.getString('reminder_last_notified_date'), isNull);
    });

    test('does not overwrite fields that are null in the map', () async {
      // Pre-set values.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('reminder_enabled', true);
      await prefs.setString('reminder_frequency', 'sixMonths');

      // Import with null enabled and frequency.
      await repo.importFromMap({
        'reminder_enabled': null,
        'reminder_frequency': null,
        'reminder_last_notified_date': null,
      });

      // Pre-existing values should be unchanged.
      expect(prefs.getBool('reminder_enabled'), isTrue);
      expect(prefs.getString('reminder_frequency'), equals('sixMonths'));
    });
  });

  group('export/import round-trip', () {
    // Property 4: Settings Export/Import Round-Trip
    // Validates: Requirements 5.3, 7.3
    test(
      'Property 4 — exportToMap after importFromMap returns equal map',
      () async {
        final testCases = [
          {
            'reminder_enabled': true,
            'reminder_frequency': 'oneMonth',
            'reminder_last_notified_date': '2025-01-10T00:00:00.000',
          },
          {
            'reminder_enabled': false,
            'reminder_frequency': 'twoWeeks',
            'reminder_last_notified_date': null,
          },
          {
            'reminder_enabled': true,
            'reminder_frequency': 'sixMonths',
            'reminder_last_notified_date': '2024-12-31T00:00:00.000',
          },
        ];

        for (final original in testCases) {
          // Reset prefs for each case.
          SharedPreferences.setMockInitialValues({});

          await repo.importFromMap(original);
          final exported = await repo.exportToMap();

          expect(
            exported['reminder_enabled'],
            equals(original['reminder_enabled']),
            reason: 'reminder_enabled mismatch for case $original',
          );
          expect(
            exported['reminder_frequency'],
            equals(original['reminder_frequency']),
            reason: 'reminder_frequency mismatch for case $original',
          );
          expect(
            exported['reminder_last_notified_date'],
            equals(original['reminder_last_notified_date']),
            reason: 'reminder_last_notified_date mismatch for case $original',
          );
        }
      },
    );

    test('round-trip with all frequency values', () async {
      final frequencies = [
        'twoWeeks',
        'oneMonth',
        'twoMonths',
        'threeMonths',
        'sixMonths',
      ];

      for (final freq in frequencies) {
        SharedPreferences.setMockInitialValues({});

        final original = {
          'reminder_enabled': true,
          'reminder_frequency': freq,
          'reminder_last_notified_date': null,
        };

        await repo.importFromMap(original);
        final exported = await repo.exportToMap();

        expect(
          exported['reminder_frequency'],
          equals(freq),
          reason: 'Round-trip failed for frequency=$freq',
        );
      }
    });
  });
}
