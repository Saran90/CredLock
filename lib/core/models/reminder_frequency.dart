enum ReminderFrequency {
  twoWeeks,
  oneMonth,
  twoMonths,
  threeMonths,
  sixMonths;

  String get label => switch (this) {
    twoWeeks => '2 Weeks',
    oneMonth => '1 Month',
    twoMonths => '2 Months',
    threeMonths => '3 Months',
    sixMonths => '6 Months',
  };

  /// Persisted key stored in shared_preferences.
  String get storageKey => name;
}
