import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/reminder_frequency.dart';
import '../../core/models/reminder_settings.dart';

abstract interface class ReminderSettingsRepository {
  Future<ReminderSettings> getSettings();
  Future<void> setEnabled(bool enabled);
  Future<void> setFrequency(ReminderFrequency frequency);
  Future<DateTime?> getLastNotifiedDate();
  Future<void> setLastNotifiedDate(DateTime date);
  Future<Map<String, dynamic>> exportToMap();
  Future<void> importFromMap(Map<String, dynamic> map);
}

class SharedPrefsReminderSettingsRepository
    implements ReminderSettingsRepository {
  SharedPrefsReminderSettingsRepository._();
  static final SharedPrefsReminderSettingsRepository instance =
      SharedPrefsReminderSettingsRepository._();

  static const _keyEnabled = 'reminder_enabled';
  static const _keyFrequency = 'reminder_frequency';
  static const _keyLastNotified = 'reminder_last_notified_date';

  @override
  Future<ReminderSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_keyEnabled);
    final stored = prefs.getString(_keyFrequency);

    if (enabled == null && stored == null) {
      return ReminderSettings.defaults;
    }

    final frequency = stored != null
        ? ReminderFrequency.values.firstWhere(
            (f) => f.storageKey == stored,
            orElse: () => ReminderFrequency.oneMonth,
          )
        : ReminderFrequency.oneMonth;

    return ReminderSettings(enabled: enabled ?? false, frequency: frequency);
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
  }

  @override
  Future<void> setFrequency(ReminderFrequency frequency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFrequency, frequency.storageKey);
  }

  @override
  Future<DateTime?> getLastNotifiedDate() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keyLastNotified);
    if (stored == null) return null;
    return DateTime.tryParse(stored);
  }

  @override
  Future<void> setLastNotifiedDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    // Store only the date part (midnight) so comparison is day-level
    final dateOnly = DateTime(date.year, date.month, date.day);
    await prefs.setString(_keyLastNotified, dateOnly.toIso8601String());
  }

  @override
  Future<Map<String, dynamic>> exportToMap() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'reminder_enabled': prefs.getBool(_keyEnabled),
      'reminder_frequency': prefs.getString(_keyFrequency),
      'reminder_last_notified_date': prefs.getString(_keyLastNotified),
    };
  }

  @override
  Future<void> importFromMap(Map<String, dynamic> map) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = map['reminder_enabled'];
    final frequency = map['reminder_frequency'];
    final lastNotified = map['reminder_last_notified_date'];
    if (enabled != null) await prefs.setBool(_keyEnabled, enabled as bool);
    if (frequency != null) {
      await prefs.setString(_keyFrequency, frequency as String);
    }
    if (lastNotified != null) {
      await prefs.setString(_keyLastNotified, lastNotified as String);
    } else {
      await prefs.remove(_keyLastNotified);
    }
  }
}
