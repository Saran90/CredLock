import 'reminder_frequency.dart';

class ReminderSettings {
  final bool enabled;
  final ReminderFrequency frequency;

  const ReminderSettings({
    required this.enabled,
    this.frequency = ReminderFrequency.oneMonth,
  });

  static const defaults = ReminderSettings(enabled: false);
}
