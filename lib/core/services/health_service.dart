import '../models/health_report.dart';
import '../models/reminder_frequency.dart';
import '../utils/password_strength_util.dart';
import '../../data/models/password_entry.dart';
import '../../data/repositories/password_repository.dart';
import '../../data/repositories/reminder_settings_repository.dart';
import 'reminder_service.dart';

/// Computes the [HealthReport] by analysing all vault entries in memory.
class HealthService {
  HealthService._();
  static final HealthService instance = HealthService._();

  Future<HealthReport> compute() async {
    final entries = await PasswordRepository.instance.getAll();

    final settings = await SharedPrefsReminderSettingsRepository.instance
        .getSettings();
    final now = DateTime.now();

    // ── Weak passwords ──────────────────────────────────────────────────────
    final weak = entries.where((e) {
      if (e.password.isEmpty) return false;
      final s = evaluatePasswordStrength(e.password);
      return s == PasswordStrength.weak || s == PasswordStrength.fair;
    }).toList();

    // ── Reused passwords ────────────────────────────────────────────────────
    final passwordCounts = <String, int>{};
    for (final e in entries) {
      if (e.password.isNotEmpty) {
        passwordCounts[e.password] = (passwordCounts[e.password] ?? 0) + 1;
      }
    }
    final reused = entries
        .where((e) => (passwordCounts[e.password] ?? 0) > 1)
        .toList();

    // ── Overdue passwords ───────────────────────────────────────────────────
    List<PasswordEntry> overdue = [];
    if (settings.enabled) {
      overdue = entries
          .where((e) => isOverdue(e, settings.frequency, now))
          .toList();
    } else {
      // Fall back to 6-month window even if reminders are off
      overdue = entries
          .where((e) => isOverdue(e, ReminderFrequency.sixMonths, now))
          .toList();
    }

    // ── Empty passwords ─────────────────────────────────────────────────────
    final empty = entries.where((e) => e.password.isEmpty).toList();

    return HealthReport(
      totalEntries: entries.length,
      weakEntries: weak,
      reusedEntries: reused,
      overdueEntries: overdue,
      emptyPasswordEntries: empty,
    );
  }
}
