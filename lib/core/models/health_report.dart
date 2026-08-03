import '../../data/models/password_entry.dart';

/// Aggregated security health data for the entire vault.
class HealthReport {
  final int totalEntries;
  final List<PasswordEntry> weakEntries;
  final List<PasswordEntry> reusedEntries;
  final List<PasswordEntry> overdueEntries;
  final List<PasswordEntry> emptyPasswordEntries;

  const HealthReport({
    required this.totalEntries,
    required this.weakEntries,
    required this.reusedEntries,
    required this.overdueEntries,
    required this.emptyPasswordEntries,
  });

  int get issueCount =>
      weakEntries.length +
      reusedEntries.length +
      overdueEntries.length +
      emptyPasswordEntries.length;

  /// Score from 0–100. Starts at 100 and deducts for each issue.
  int get score {
    if (totalEntries == 0) return 100;
    int deductions = 0;
    deductions += weakEntries.length * 15;
    deductions += reusedEntries.length * 20;
    deductions += overdueEntries.length * 10;
    deductions += emptyPasswordEntries.length * 10;
    return (100 - deductions).clamp(0, 100);
  }

  String get scoreLabel {
    final s = score;
    if (s >= 90) return 'Excellent';
    if (s >= 75) return 'Good';
    if (s >= 50) return 'Fair';
    if (s >= 25) return 'Poor';
    return 'Critical';
  }
}
