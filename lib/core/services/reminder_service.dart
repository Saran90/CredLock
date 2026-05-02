import 'dart:math';
import 'package:workmanager/workmanager.dart';
import '../models/reminder_frequency.dart';
import '../../data/models/password_entry.dart';
import '../../data/repositories/password_repository.dart';
import '../../data/repositories/reminder_settings_repository.dart';
import 'encryption_service.dart';
import 'notification_service.dart';

/// Top-level callback dispatcher for workmanager — must be a top-level function.
/// The @pragma annotation prevents tree-shaking in release builds.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == ReminderService._backgroundTaskName) {
      return ReminderService.backgroundTaskHandler();
    }
    return Future.value(false);
  });
}

/// Returns true if [entry] is overdue given [frequency] and [now].
/// [now] is normalised to midnight before comparison.
/// This is a top-level pure function for easy testability.
bool isOverdue(PasswordEntry entry, ReminderFrequency frequency, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final updated = DateTime(
    entry.lastUpdatedAt.year,
    entry.lastUpdatedAt.month,
    entry.lastUpdatedAt.day,
  );
  return switch (frequency) {
    ReminderFrequency.twoWeeks => today.difference(updated).inDays >= 14,
    ReminderFrequency.oneMonth => today.compareTo(_addMonths(updated, 1)) >= 0,
    ReminderFrequency.twoMonths => today.compareTo(_addMonths(updated, 2)) >= 0,
    ReminderFrequency.threeMonths =>
      today.compareTo(_addMonths(updated, 3)) >= 0,
    ReminderFrequency.sixMonths => today.compareTo(_addMonths(updated, 6)) >= 0,
  };
}

/// Adds [months] calendar months to [date], clamping to the last day of
/// the resulting month (e.g. Jan 31 + 1 month = Feb 28/29).
DateTime _addMonths(DateTime date, int months) {
  final targetMonth = date.month + months;
  final year = date.year + (targetMonth - 1) ~/ 12;
  final month = ((targetMonth - 1) % 12) + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, min(date.day, lastDay));
}

class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  static const _backgroundTaskName = 'credlock_password_reminder';

  final _settingsRepo = SharedPrefsReminderSettingsRepository.instance;
  final _passwordRepo = PasswordRepository.instance;
  final _notificationService = NotificationService.instance;

  /// Called once at app startup from main.dart.
  /// Schedules background task and runs foreground check if reminders are enabled.
  Future<void> init() async {
    final settings = await _settingsRepo.getSettings();
    if (!settings.enabled) return;
    await _scheduleBackgroundTask();
    await performForegroundCheck();
  }

  /// Called when the app comes to the foreground (via WidgetsBindingObserver).
  /// No-op if reminders are disabled.
  Future<void> performForegroundCheck() async {
    final settings = await _settingsRepo.getSettings();
    if (!settings.enabled) return;
    await evaluate();
  }

  /// Evaluates all password entries and shows a notification if any are overdue.
  /// Notification is shown at most once per calendar day.
  /// Returns the list of overdue entries.
  Future<List<PasswordEntry>> evaluate() async {
    final settings = await _settingsRepo.getSettings();
    if (!settings.enabled) return [];

    final entries = await _passwordRepo.getAll();
    final now = DateTime.now();
    final overdue = entries
        .where((e) => isOverdue(e, settings.frequency, now))
        .toList();

    if (overdue.isNotEmpty) {
      // Only notify once per calendar day
      final lastNotified = await _settingsRepo.getLastNotifiedDate();
      final today = DateTime(now.year, now.month, now.day);
      final alreadyNotifiedToday =
          lastNotified != null &&
          lastNotified.year == today.year &&
          lastNotified.month == today.month &&
          lastNotified.day == today.day;

      if (!alreadyNotifiedToday) {
        await _notificationService.showReminderNotification(
          overdue.map((e) => e.name).toList(),
        );
        await _settingsRepo.setLastNotifiedDate(now);
      }
    }

    return overdue;
  }

  /// Entry point called by workmanager in the background isolate.
  /// Re-initialises EncryptionService since this runs in a separate isolate.
  static Future<bool> backgroundTaskHandler() async {
    try {
      await EncryptionService.instance.init();
      await ReminderService.instance.evaluate();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Schedules the 24-hour periodic background task.
  Future<void> _scheduleBackgroundTask() async {
    await Workmanager().registerPeriodicTask(
      _backgroundTaskName,
      _backgroundTaskName,
      frequency: const Duration(hours: 24),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  /// Cancels the scheduled background task.
  Future<void> cancelSchedule() async {
    await Workmanager().cancelByUniqueName(_backgroundTaskName);
  }
}
