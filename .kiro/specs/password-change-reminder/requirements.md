# Requirements Document

## Introduction

The Password Change Reminder feature adds proactive security hygiene to CredLock by notifying users when their stored passwords have not been updated within a user-defined period. Users can enable or disable the feature globally and choose a reminder frequency. The app evaluates each password entry's `lastUpdatedAt` date against the current date and delivers local notifications listing the passwords that are overdue for a change. Settings persist across app restarts, and checks run both when the app is opened and via scheduled background checks.

## Glossary

- **Reminder_Service**: The core service responsible for evaluating password age, determining which entries are overdue, and triggering notifications.
- **Notification_Service**: The service responsible for scheduling, displaying, and cancelling local notifications via `flutter_local_notifications`.
- **Settings_Repository**: The persistence layer responsible for storing and retrieving reminder settings using `shared_preferences`.
- **Settings_Screen**: The Flutter screen within the Settings tab where the user configures the reminder toggle and frequency.
- **Password_Entry**: A single stored credential record in the CredLock vault, containing a `createdAt` timestamp (the date the entry was first created) and a `lastUpdatedAt` timestamp (the date the entry's password was most recently changed).
- **Reminder_Frequency**: The user-selected duration after which a password is considered overdue. Valid values: 2 weeks, 1 month, 2 months, 3 months, 6 months.
- **Overdue_Password**: A `Password_Entry` whose `lastUpdatedAt` date is older than the threshold derived from the current date minus the selected `Reminder_Frequency`.
- **Foreground_Check**: A reminder evaluation triggered when the app transitions to the foreground or the home screen is loaded.
- **Background_Check**: A reminder evaluation triggered by a scheduled periodic task while the app is not in the foreground.

---

## Requirements

### Requirement 1: Reminder Toggle

**User Story:** As a CredLock user, I want to enable or disable the password change reminder feature, so that I can opt in or out of receiving password age notifications.

#### Acceptance Criteria

1. THE `Settings_Screen` SHALL display a toggle control labelled "Password Change Reminder" that reflects the current enabled/disabled state of the reminder feature.
2. WHEN the user activates the toggle, THE `Settings_Repository` SHALL persist the enabled state so that it survives app restarts.
3. WHEN the user deactivates the toggle, THE `Settings_Repository` SHALL persist the disabled state and THE `Notification_Service` SHALL cancel all pending reminder notifications.
4. WHEN the app starts and the reminder feature is disabled, THE `Reminder_Service` SHALL perform no password age evaluation.

---

### Requirement 2: Reminder Frequency Selection

**User Story:** As a CredLock user, I want to choose how often I am reminded to update my passwords, so that the reminders match my personal security preferences.

#### Acceptance Criteria

1. WHILE the reminder feature is enabled, THE `Settings_Screen` SHALL display a frequency selector offering exactly the following options: 2 weeks, 1 month, 2 months, 3 months, 6 months.
2. WHEN the user selects a frequency option, THE `Settings_Repository` SHALL persist the selected `Reminder_Frequency` so that it survives app restarts.
3. WHEN the app starts and the reminder feature is enabled, THE `Settings_Screen` SHALL display the previously persisted `Reminder_Frequency` as the selected value.
4. IF the reminder feature is enabled and no frequency has been previously persisted, THEN THE `Settings_Repository` SHALL default the `Reminder_Frequency` to 1 month.
5. WHILE the reminder feature is disabled, THE `Settings_Screen` SHALL display the frequency selector in a visually disabled state and SHALL NOT allow the user to change the frequency.

---

### Requirement 3: Password Age Evaluation

**User Story:** As a CredLock user, I want the app to automatically identify which of my passwords are overdue for a change, so that I know exactly which credentials need attention.

#### Acceptance Criteria

1. WHEN the `Reminder_Service` performs an evaluation, THE `Reminder_Service` SHALL retrieve all `Password_Entry` records from the database.
2. WHEN the `Reminder_Service` performs an evaluation, THE `Reminder_Service` SHALL compare each `Password_Entry`'s `lastUpdatedAt` date to the current date using the persisted `Reminder_Frequency` to determine if the entry is an `Overdue_Password`.
3. WHEN the selected `Reminder_Frequency` is 2 weeks, THE `Reminder_Service` SHALL classify a `Password_Entry` as an `Overdue_Password` if the number of days elapsed since `lastUpdatedAt` is greater than or equal to 14.
4. WHEN the selected `Reminder_Frequency` is a month-based option (1 month, 2 months, 3 months, or 6 months), THE `Reminder_Service` SHALL classify a `Password_Entry` as an `Overdue_Password` if the current date is on or after the calendar date obtained by adding the corresponding number of months to `lastUpdatedAt` (e.g., a `lastUpdatedAt` of January 15 with a 1-month frequency becomes overdue on February 15).
5. WHEN the `Reminder_Service` performs an evaluation and no `Overdue_Password` entries exist, THE `Reminder_Service` SHALL not trigger any notification.
6. THE `Reminder_Service` SHALL evaluate password age using the device's local date at the time of the check, with day-level precision (time-of-day SHALL be ignored).

---

### Requirement 4: Foreground Notification Trigger

**User Story:** As a CredLock user, I want to be notified about overdue passwords when I open the app, so that I am reminded at a natural point of interaction.

#### Acceptance Criteria

1. WHEN the app transitions to the foreground and the reminder feature is enabled, THE `Reminder_Service` SHALL perform a `Foreground_Check` within 3 seconds of the app becoming active.
2. WHEN a `Foreground_Check` identifies one or more `Overdue_Password` entries, THE `Notification_Service` SHALL display a local notification listing the names of all `Overdue_Password` entries.
3. WHEN a `Foreground_Check` identifies exactly one `Overdue_Password`, THE `Notification_Service` SHALL display a notification with the title "Password Update Reminder" and a body that includes the name of that entry.
4. WHEN a `Foreground_Check` identifies two or more `Overdue_Password` entries, THE `Notification_Service` SHALL display a notification with the title "Password Update Reminder" and a body that lists all overdue entry names.
5. WHEN a `Foreground_Check` identifies one or more `Overdue_Password` entries, THE `Notification_Service` SHALL replace any previously displayed reminder notification rather than stacking duplicate notifications.

---

### Requirement 5: Background Notification Trigger

**User Story:** As a CredLock user, I want to receive reminders even when I haven't opened the app recently, so that overdue passwords don't go unnoticed.

#### Acceptance Criteria

1. WHEN the reminder feature is enabled, THE `Reminder_Service` SHALL schedule a periodic `Background_Check` to run once every 24 hours.
2. WHEN a `Background_Check` identifies one or more `Overdue_Password` entries, THE `Notification_Service` SHALL display a local notification using the same format defined in Requirement 4.
3. WHEN the reminder feature is disabled, THE `Reminder_Service` SHALL cancel any scheduled `Background_Check`.
4. WHEN the app is reinstalled or the device is restarted, THE `Reminder_Service` SHALL reschedule the `Background_Check` on the next app launch if the reminder feature is enabled.
5. IF the device does not grant notification permission, THEN THE `Notification_Service` SHALL log the permission denial and SHALL NOT attempt to display notifications until permission is granted.

---

### Requirement 6: Notification Permission Handling

**User Story:** As a CredLock user, I want the app to request notification permission in a clear and timely manner, so that I can make an informed decision about enabling reminders.

#### Acceptance Criteria

1. WHEN the user enables the reminder toggle for the first time, THE `Notification_Service` SHALL request notification permission from the operating system before scheduling any checks.
2. WHEN the operating system grants notification permission, THE `Reminder_Service` SHALL proceed to schedule the `Background_Check` and perform an immediate `Foreground_Check`.
3. IF the operating system denies notification permission, THEN THE `Settings_Screen` SHALL display an inline message informing the user that notifications are required for reminders to work, and SHALL provide a button to open the device's app settings.
4. IF the operating system denies notification permission, THEN THE `Settings_Repository` SHALL retain the enabled state as true so that the reminder activates automatically if the user later grants permission.

---

### Requirement 7: Settings Persistence

**User Story:** As a CredLock user, I want my reminder preferences to be saved automatically, so that I do not have to reconfigure the feature every time I open the app.

#### Acceptance Criteria

1. THE `Settings_Repository` SHALL persist the reminder enabled/disabled state using a key-value store that survives app termination and device restarts.
2. THE `Settings_Repository` SHALL persist the selected `Reminder_Frequency` using a key-value store that survives app termination and device restarts.
3. WHEN the app starts, THE `Settings_Repository` SHALL load the persisted reminder state and frequency before the `Reminder_Service` performs any evaluation.
4. IF no persisted reminder state exists on first launch, THEN THE `Settings_Repository` SHALL default the reminder feature to disabled.

---

### Requirement 8: Settings UI Integration

**User Story:** As a CredLock user, I want the reminder settings to be accessible from the main Settings tab, so that I can find and adjust them without navigating to a separate section.

#### Acceptance Criteria

1. THE `Settings_Screen` SHALL be accessible from the Settings tab in the bottom navigation bar of the home screen.
2. THE `Settings_Screen` SHALL display the reminder toggle and frequency selector as described in Requirements 1 and 2.
3. WHEN the `Settings_Screen` is displayed, THE `Settings_Screen` SHALL reflect the current persisted state of the reminder toggle and frequency without requiring a manual refresh.
4. THE `Settings_Screen` SHALL display the reminder section with a section heading labelled "Password Reminders".

---

### Requirement 9: Password Entry `lastUpdatedAt` Field

**User Story:** As a CredLock user, I want the reminder timer to reset whenever I update a password entry, so that recently changed passwords are not incorrectly flagged as overdue.

#### Acceptance Criteria

1. THE `Password_Entry` model SHALL include a `lastUpdatedAt` field of type `DateTime` alongside the existing `createdAt` field.
2. WHEN a new `Password_Entry` is created, THE `Password_Entry` SHALL set `lastUpdatedAt` equal to `createdAt` so that both fields reflect the creation date.
3. WHEN a user edits and saves an existing `Password_Entry`, THE `Password_Entry` SHALL set `lastUpdatedAt` to the current date and time at the moment the save operation completes.
4. THE `Password_Entry` model's `toMap` method SHALL serialise `lastUpdatedAt` to the `last_updated_at` column and the `fromMap` factory SHALL deserialise it back to a `DateTime`.

---

### Requirement 10: Database Migration for `last_updated_at` Column

**User Story:** As a CredLock developer, I want the database schema to include the `last_updated_at` column, so that `lastUpdatedAt` values are persisted correctly for all existing and new password entries.

#### Acceptance Criteria

1. THE `DatabaseHelper` SHALL define a database migration that adds a `last_updated_at` column of type `TEXT NOT NULL` to the `passwords` table when upgrading from a schema version that does not contain this column.
2. WHEN the migration runs, THE `DatabaseHelper` SHALL set the default value of `last_updated_at` for all existing rows to the value of their existing `created_at` column, so that no existing entry is immediately flagged as overdue due to a null timestamp.
3. WHEN a new `passwords` table is created, THE `DatabaseHelper` SHALL include the `last_updated_at` column in the `CREATE TABLE` statement with a `NOT NULL` constraint.
4. WHEN the migration completes, THE `DatabaseHelper` SHALL increment the database schema version number to reflect the structural change.
