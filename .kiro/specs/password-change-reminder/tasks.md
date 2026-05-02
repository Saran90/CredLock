# Implementation Plan: Password Change Reminder

## Overview

Implement the password change reminder feature for CredLock by adding the `lastUpdatedAt` field to `PasswordEntry`, migrating the database to v3, building the settings/notification/reminder service layer, wiring up a new `SettingsScreen`, and configuring platform-specific background task support on Android and iOS.

## Tasks

- [x] 1. Add new dependencies to `pubspec.yaml`
  - Add `flutter_local_notifications: ^18.0.1`, `shared_preferences: ^2.3.5`, and `workmanager: ^0.9.0` under `dependencies`
  - Run `flutter pub get` to resolve the packages
  - _Requirements: 5.1, 6.1_

- [x] 2. Update `PasswordEntry` model with `lastUpdatedAt`
  - [x] 2.1 Add `lastUpdatedAt` field and update constructor, `toMap`, `fromMap`, and `copyWith`
    - Add `final DateTime lastUpdatedAt;` field to `lib/data/models/password_entry.dart`
    - Update the constructor to accept `DateTime? lastUpdatedAt` and default it to `createdAt` using an initialiser list
    - Add `'last_updated_at': lastUpdatedAt.toIso8601String()` to `toMap()`
    - Add `lastUpdatedAt` deserialisation to `fromMap()` with fallback to `created_at` for pre-migration rows
    - Add `DateTime? lastUpdatedAt` parameter to `copyWith()` and wire it through
    - _Requirements: 9.1, 9.2, 9.4_

  - [ ]* 2.2 Write property test: serialisation round-trip preserves `lastUpdatedAt`
    - **Property 6: `PasswordEntry` serialisation round-trip preserves `lastUpdatedAt`**
    - **Validates: Requirement 9.4**
    - File: `test/data/models/password_entry_test.dart`
    - Use `glados` or `fast_check` to generate arbitrary `PasswordEntry` values with arbitrary `lastUpdatedAt` `DateTime`
    - Assert `PasswordEntry.fromMap(entry.toMap()).lastUpdatedAt == entry.lastUpdatedAt` (second-level precision)
    - Tag: `// Feature: password-change-reminder, Property 6: PasswordEntry serialisation round-trip preserves lastUpdatedAt`

  - [ ]* 2.3 Write property test: new entry `lastUpdatedAt == createdAt`
    - **Property 7: New `PasswordEntry` has `lastUpdatedAt == createdAt`**
    - **Validates: Requirement 9.2**
    - File: `test/data/models/password_entry_test.dart`
    - Generate arbitrary `DateTime` values as `createdAt`; construct `PasswordEntry` without explicit `lastUpdatedAt`
    - Assert `entry.lastUpdatedAt == entry.createdAt`
    - Tag: `// Feature: password-change-reminder, Property 7: New PasswordEntry has lastUpdatedAt == createdAt`

- [x] 3. Migrate database to v3 and update `PasswordRepository`
  - [x] 3.1 Update `DatabaseHelper` to schema version 3
    - Bump `_dbVersion` to `3` in `lib/data/db/database_helper.dart`
    - Add `last_updated_at TEXT NOT NULL` to the `CREATE TABLE` statement in `_onCreate`
    - Add a migration branch `if (oldVersion < 3)` in `_onUpgrade` that `ALTER TABLE` adds `last_updated_at TEXT`, then back-fills it with `UPDATE ... SET last_updated_at = created_at WHERE last_updated_at IS NULL`
    - _Requirements: 10.1, 10.2, 10.3, 10.4_

  - [x] 3.2 Stamp `lastUpdatedAt` on save in `PasswordRepository.update()`
    - In `lib/data/repositories/password_repository.dart`, call `entry.copyWith(lastUpdatedAt: DateTime.now())` before persisting in `update()`
    - _Requirements: 9.3_

- [x] 4. Create `ReminderFrequency` enum and `ReminderSettings` value object
  - Create `lib/core/models/reminder_frequency.dart` with the `ReminderFrequency` enum (values: `twoWeeks`, `oneMonth`, `twoMonths`, `threeMonths`, `sixMonths`), a `label` getter, and a `storageKey` getter
  - Create `lib/core/models/reminder_settings.dart` with the `ReminderSettings` class (fields: `enabled`, `frequency`), a `const` constructor defaulting `frequency` to `oneMonth`, and a `static const defaults` with `enabled: false`
  - _Requirements: 2.1, 2.4, 7.4_

- [x] 5. Implement `ReminderSettingsRepository`
  - [x] 5.1 Create `SharedPrefsReminderSettingsRepository`
    - Create `lib/data/repositories/reminder_settings_repository.dart`
    - Define the `abstract interface class ReminderSettingsRepository` with `getSettings()`, `setEnabled()`, and `setFrequency()` methods
    - Implement `SharedPrefsReminderSettingsRepository` using `SharedPreferences` with keys `reminder_enabled` and `reminder_frequency`
    - `getSettings()` must return `ReminderSettings.defaults` when no persisted value exists
    - `setFrequency()` must persist the enum's `storageKey`; `getSettings()` must parse it back
    - _Requirements: 1.2, 1.3, 2.2, 2.4, 7.1, 7.2, 7.3, 7.4_

  - [ ]* 5.2 Write property test: frequency round-trip
    - **Property 1: Settings frequency round-trip**
    - **Validates: Requirements 2.2, 7.2**
    - File: `test/data/repositories/reminder_settings_repository_test.dart`
    - Generate arbitrary `ReminderFrequency` enum values; call `setFrequency(f)` then `getSettings()` and assert `result.frequency == f`
    - Use an in-memory or mocked `SharedPreferences` instance
    - Tag: `// Feature: password-change-reminder, Property 1: Settings frequency round-trip`

- [x] 6. Implement `NotificationService`
  - [x] 6.1 Create `NotificationService` singleton
    - Create `lib/core/services/notification_service.dart`
    - Implement `init()` to initialise `FlutterLocalNotificationsPlugin` with Android and iOS settings and create the `password_reminders` notification channel
    - Implement `requestPermission()` returning `true` if permission is granted or already granted
    - Implement `hasPermission()` to check current permission status without requesting
    - Implement `showReminderNotification(List<String> overdueNames)` using fixed ID `1001`, title `"Password Update Reminder"`, and the body format from the design (single entry vs. multiple entries)
    - Implement `cancelReminderNotification()` to cancel notification ID `1001`
    - _Requirements: 1.3, 4.2, 4.3, 4.4, 4.5, 5.2, 5.5, 6.1, 6.2_

  - [ ]* 6.2 Write property test: notification body contains all overdue entry names
    - **Property 5: Notification body contains all overdue entry names**
    - **Validates: Requirements 4.2, 4.3, 4.4**
    - File: `test/core/services/notification_service_test.dart`
    - Generate arbitrary non-empty lists of `PasswordEntry` records; call the body-formatting logic and assert every entry's `name` appears in the resulting string
    - Extract the body-building logic into a testable pure function if needed
    - Tag: `// Feature: password-change-reminder, Property 5: Notification body contains all overdue entry names`

- [x] 7. Implement `ReminderService` with `isOverdue` and background task
  - [x] 7.1 Create `ReminderService` with `isOverdue` pure function and `evaluate()`
    - Create `lib/core/services/reminder_service.dart`
    - Implement the top-level `callbackDispatcher()` function annotated with `@pragma('vm:entry-point')` that calls `Workmanager().executeTask(...)` and delegates to `ReminderService.backgroundTaskHandler()`
    - Implement `isOverdue(PasswordEntry entry, ReminderFrequency frequency, DateTime now)` as a standalone function using the calendar-month arithmetic described in the design (`_addMonths` helper with end-of-month clamping)
    - Implement `evaluate()` to load settings, fetch all passwords, filter overdue entries, and call `NotificationService.showReminderNotification()` only when the list is non-empty
    - Implement `init()` to load settings and, if enabled, schedule the background task and call `performForegroundCheck()`
    - Implement `performForegroundCheck()` as a no-op when reminders are disabled
    - Implement `backgroundTaskHandler()` as a static method that re-initialises `EncryptionService` and calls `evaluate()`
    - Implement `_scheduleBackgroundTask()` using `Workmanager().registerPeriodicTask()` with a 24-hour frequency and `ExistingWorkPolicy.keep`
    - Implement `_cancelBackgroundTask()` using `Workmanager().cancelByUniqueName()`
    - _Requirements: 1.4, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 4.1, 5.1, 5.3, 5.4_

  - [ ]* 7.2 Write property test: overdue classification for all frequencies
    - **Property 2: Overdue classification matches threshold for all frequencies**
    - **Validates: Requirements 3.2, 3.3, 3.4**
    - File: `test/core/services/reminder_service_test.dart`
    - Generate arbitrary `DateTime` pairs (`lastUpdatedAt`, `now`) and arbitrary `ReminderFrequency` values
    - Assert `isOverdue(entry, frequency, now)` returns `true` iff the appropriate threshold condition holds (14-day rule for `twoWeeks`; calendar-month comparison for the rest)
    - Tag: `// Feature: password-change-reminder, Property 2: Overdue classification matches threshold for all frequencies`

  - [ ]* 7.3 Write property test: day-level precision
    - **Property 3: Day-level precision — time-of-day does not affect overdue classification**
    - **Validates: Requirement 3.6**
    - File: `test/core/services/reminder_service_test.dart`
    - Generate an arbitrary calendar date and two `DateTime` values on that same date with different times (e.g. midnight vs. 23:59); assert `isOverdue` returns the same result for both
    - Tag: `// Feature: password-change-reminder, Property 3: Day-level precision — time-of-day does not affect overdue classification`

  - [ ]* 7.4 Write property test: no notification when no entries are overdue
    - **Property 4: No notification when no entries are overdue**
    - **Validates: Requirement 3.5**
    - File: `test/core/services/reminder_service_test.dart`
    - Generate arbitrary lists of `PasswordEntry` records where every entry's `lastUpdatedAt` is strictly within the frequency threshold; mock `NotificationService`; call `evaluate()` and assert `showReminderNotification` is never called
    - Tag: `// Feature: password-change-reminder, Property 4: No notification when no entries are overdue`

- [x] 8. Checkpoint — Ensure all service-layer tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 9. Create `SettingsScreen` and wire it into `HomeScreen`
  - [x] 9.1 Create `SettingsScreen` with reminder toggle and frequency selector
    - Create `lib/features/settings/settings_screen.dart`
    - Implement `SettingsScreen` as a `StatefulWidget` that loads `ReminderSettings` from `ReminderSettingsRepository` and checks notification permission via `NotificationService.hasPermission()` on mount
    - Render a `ListView` with a "Password Reminders" section heading, a `SwitchListTile` labelled "Password Change Reminder", and (when enabled) a row of `ChoiceChip` widgets for the five frequency options
    - Toggle-on flow: call `NotificationService.requestPermission()`; if granted call `ReminderService.init()`; if denied show `PermissionWarningBanner` and retain `enabled = true` in storage
    - Toggle-off flow: call `NotificationService.cancelReminderNotification()` and `ReminderService._cancelBackgroundTask()` (expose a public `cancelSchedule()` method on `ReminderService`)
    - Frequency chip selection: call `ReminderSettingsRepository.setFrequency()` immediately on tap
    - Render the frequency selector wrapped in `IgnorePointer` with reduced opacity when `enabled == false`
    - Implement `PermissionWarningBanner` inline widget with warning icon, explanatory text, and an "Open Settings" `TextButton` that opens device app settings
    - _Requirements: 1.1, 1.2, 1.3, 2.1, 2.2, 2.3, 2.5, 6.3, 6.4, 8.1, 8.2, 8.3, 8.4_

  - [x] 9.2 Replace the Settings placeholder in `HomeScreen` and add `WidgetsBindingObserver`
    - In `lib/features/home/home_screen.dart`, replace `const _PlaceholderScreen(label: 'Settings')` with `const SettingsScreen()` and add the required import
    - Mix `WidgetsBindingObserver` into `_HomeScreenState`, register/unregister the observer in `initState`/`dispose`, and call `ReminderService.instance.performForegroundCheck()` in `didChangeAppLifecycleState` when `state == AppLifecycleState.resumed`
    - _Requirements: 4.1, 8.1_

- [x] 10. Update `main.dart` for service initialisation
  - In `lib/main.dart`, after `EncryptionService.instance.init()`, add:
    1. `await Workmanager().initialize(callbackDispatcher, isInDebugMode: false)`
    2. `await NotificationService.instance.init()`
    3. `await ReminderService.instance.init()`
  - Add the required imports for `Workmanager`, `NotificationService`, `ReminderService`, and `callbackDispatcher`
  - _Requirements: 5.4, 7.3_

- [x] 11. Android platform configuration
  - [x] 11.1 Update `android/app/build.gradle.kts` for desugaring
    - Add `multiDexEnabled = true` to `defaultConfig`
    - Set `isCoreLibraryDesugaringEnabled = true` in `compileOptions`
    - Ensure `sourceCompatibility` and `targetCompatibility` are set to `JavaVersion.VERSION_17`
    - Add `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")` to `dependencies`
    - _Requirements: 5.1_

  - [x] 11.2 Add permissions to `android/app/src/main/AndroidManifest.xml`
    - Add `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, and `SCHEDULE_EXACT_ALARM` `<uses-permission>` entries
    - _Requirements: 5.1, 6.1_

- [x] 12. iOS platform configuration
  - [x] 12.1 Update `ios/Runner/AppDelegate.swift`
    - Add `import flutter_local_notifications` and the `FlutterLocalNotificationsPlugin.setPluginRegistrantCallback` call inside `application(_:didFinishLaunchingWithOptions:)`
    - Set `UNUserNotificationCenter.current().delegate` for iOS 10+
    - _Requirements: 5.1, 6.1_

  - [x] 12.2 Update `ios/Runner/Info.plist` for background modes
    - Add `BGTaskSchedulerPermittedIdentifiers` array with the workmanager background task identifier
    - Add `UIBackgroundModes` array with `fetch` and `processing` entries
    - _Requirements: 5.1_

- [x] 13. Final checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties; unit tests validate specific examples and edge cases
- The `callbackDispatcher` top-level function must live in `lib/core/services/reminder_service.dart` (or `lib/main.dart`) and be annotated with `@pragma('vm:entry-point')` to survive tree-shaking
- Opening device app settings in `PermissionWarningBanner` can use `app_settings` package or `url_launcher` — pick whichever is already present or add `app_settings` as a dependency
- The `_cancelBackgroundTask` method should be exposed as a public `cancelSchedule()` method on `ReminderService` so `SettingsScreen` can call it without accessing private members
