# Requirements Document

## Introduction

This feature adds Google Sign-In as the authentication mechanism for CredLock and enables users to back up and restore their vault data (SQLite database + reminder settings) to and from their personal Google Drive app data folder. The existing placeholder login screen is replaced with a Google Sign-In screen. The splash screen gains an auth-check gate so already-signed-in users skip the login screen. A new "Account" section in Settings exposes the signed-in user's identity, backup, restore, and sign-out actions.

All vault data remains AES-encrypted at rest in the SQLite database. The AES-256 encryption key is derived deterministically from the user's Google account ID using HKDF-SHA256 with a fixed app-specific salt, making it reproducible on any device the user signs into. The backup uploads the raw encrypted database file plus a JSON file of reminder settings — no decryption occurs during backup or restore.

## Glossary

- **App**: The CredLock Flutter application.
- **Auth_Service**: The component responsible for Google Sign-In and sign-out operations.
- **Backup_Service**: The component responsible for packaging and uploading backup files to Google Drive.
- **Restore_Service**: The component responsible for listing, downloading, and applying backup files from Google Drive.
- **Drive_Client**: The HTTP client that communicates with the Google Drive REST API using the signed-in user's OAuth token.
- **AppDataFolder**: The private, app-specific storage space in Google Drive (`appDataFolder` scope) that is not visible in the user's Drive UI.
- **Backup_Bundle**: A timestamped set of two files — `credlock.db` (the SQLite database) and `settings.json` (reminder settings) — stored together in the AppDataFolder.
- **Settings_Snapshot**: A JSON object containing the three reminder settings keys: `reminder_enabled`, `reminder_frequency`, and `reminder_last_notified_date`.
- **SplashScreen**: The animated launch screen that determines where to route the user on startup.
- **LoginScreen**: The screen presenting the Google Sign-In button.
- **HomeScreen**: The main screen with the vault, add, and settings tabs.
- **SettingsScreen**: The screen containing app configuration options.
- **Account_Section**: The new section within SettingsScreen that shows user identity and exposes backup, restore, and sign-out actions.
- **Vault_DB**: The SQLite database file (`credlock.db`) managed by `DatabaseHelper`.
- **Key_Derivation_Service**: The component responsible for deriving the AES-256 encryption key deterministically from the signed-in user's Google account ID using HKDF-SHA256 with a fixed app-specific salt.
- **Derived_Key**: The AES-256 key produced by the Key_Derivation_Service from the user's Google ID. It is identical on every device where the same Google account is signed in.

---

## Requirements

### Requirement 1: Google Sign-In Authentication

**User Story:** As a CredLock user, I want to sign in with my Google account, so that my identity is verified before I can access the vault.

#### Acceptance Criteria

1. THE LoginScreen SHALL display a single "Sign in with Google" button that conforms to Google's branding guidelines, replacing the existing email/password form.
2. WHEN the user taps the "Sign in with Google" button, THE Auth_Service SHALL initiate the Google OAuth sign-in flow requesting the `email`, `profile`, and `https://www.googleapis.com/auth/drive.appdata` scopes.
3. WHEN the Google sign-in flow completes successfully, THE App SHALL navigate to HomeScreen and dismiss LoginScreen from the navigation stack.
4. IF the Google sign-in flow is cancelled by the user, THEN THE LoginScreen SHALL remain visible and display no error message.
5. IF the Google sign-in flow fails due to a network or server error, THEN THE LoginScreen SHALL display an error message describing the failure.
6. THE Auth_Service SHALL persist the signed-in session so that the user remains authenticated across app restarts without re-authenticating.

---

### Requirement 2: Authentication Gate on Startup

**User Story:** As a CredLock user, I want the app to remember my sign-in state, so that I am not forced to sign in every time I open the app.

#### Acceptance Criteria

1. WHEN the SplashScreen animation completes, THE SplashScreen SHALL check whether a valid Google sign-in session exists.
2. IF a valid session exists, THEN THE SplashScreen SHALL navigate to HomeScreen.
3. IF no valid session exists, THEN THE SplashScreen SHALL navigate to LoginScreen.
4. THE Auth_Service SHALL expose a synchronous-readable signed-in state so the SplashScreen can query it after the animation without an additional loading delay.

---

### Requirement 3: Signed-In User Profile Access

**User Story:** As a CredLock user, I want to see my Google account details in Settings, so that I know which account is linked to my vault.

#### Acceptance Criteria

1. WHEN the user is signed in, THE Auth_Service SHALL provide the signed-in user's display name, email address, and profile photo URL.
2. WHEN the Account_Section is rendered, THE SettingsScreen SHALL display the signed-in user's display name and email address.
3. WHERE a profile photo URL is available, THE SettingsScreen SHALL display the user's profile photo as a circular avatar in the Account_Section.
4. IF the profile photo URL is unavailable or fails to load, THEN THE SettingsScreen SHALL display a fallback avatar using the user's initials.

---

### Requirement 4: Sign-Out

**User Story:** As a CredLock user, I want to sign out of my Google account, so that another person using my device cannot access my vault.

#### Acceptance Criteria

1. THE Account_Section SHALL contain a "Sign Out" action.
2. WHEN the user taps "Sign Out", THE App SHALL display a confirmation dialog before proceeding.
3. WHEN the user confirms sign-out, THE Auth_Service SHALL revoke the local Google sign-in session and navigate to LoginScreen, clearing the navigation stack.
4. WHEN the user dismisses the confirmation dialog without confirming, THE App SHALL remain on SettingsScreen with the session intact.
5. WHEN sign-out completes, THE App SHALL not retain any cached user profile data in memory.

---

### Requirement 5: Backup to Google Drive

**User Story:** As a CredLock user, I want to back up my vault to Google Drive, so that I can recover my passwords if I lose or replace my device.

#### Acceptance Criteria

1. THE Account_Section SHALL contain a "Backup to Google Drive" action.
2. WHEN the user initiates a backup, THE Backup_Service SHALL close any open database connections, read the Vault_DB file from the device filesystem, and read the three reminder settings keys from SharedPreferences.
3. WHEN the user initiates a backup, THE Backup_Service SHALL create a Settings_Snapshot JSON file containing `reminder_enabled`, `reminder_frequency`, and `reminder_last_notified_date`.
4. WHEN the user initiates a backup, THE Backup_Service SHALL upload both the Vault_DB file and the Settings_Snapshot JSON file to the AppDataFolder using the Drive_Client, naming each file with a UTC timestamp in the format `credlock_backup_<YYYY-MM-DDTHHmmss>Z.db` and `credlock_backup_<YYYY-MM-DDTHHmmss>Z_settings.json` respectively.
5. WHILE a backup is in progress, THE App SHALL display a progress indicator and prevent the user from initiating a second backup.
6. WHEN the backup completes successfully, THE App SHALL display a success message indicating the backup timestamp.
7. IF the backup fails due to a network error or Drive API error, THEN THE Backup_Service SHALL surface an error message to the user and leave the existing backups in the AppDataFolder unchanged.
8. THE Backup_Service SHALL upload the Vault_DB file as-is without decrypting its contents. The Vault_DB is encrypted with the Derived_Key, which is reproducible from the user's Google account on any device, enabling cross-device restore.

---

### Requirement 6: List and Select Backups for Restore

**User Story:** As a CredLock user, I want to see a list of my available backups, so that I can choose which backup to restore.

#### Acceptance Criteria

1. WHEN the user taps "Restore from Google Drive", THE Restore_Service SHALL query the AppDataFolder via the Drive_Client and return a list of available Backup_Bundles sorted by timestamp descending (newest first).
2. WHEN the backup list is retrieved, THE App SHALL display each backup entry showing its UTC timestamp formatted as a human-readable local date and time.
3. IF no backups exist in the AppDataFolder, THEN THE App SHALL display a message indicating that no backups are available.
4. IF the backup list query fails due to a network or Drive API error, THEN THE App SHALL display an error message and allow the user to retry.
5. WHILE the backup list is loading, THE App SHALL display a loading indicator.

---

### Requirement 7: Restore from Google Drive

**User Story:** As a CredLock user, I want to restore my vault from a Google Drive backup, so that I can recover my data after a device change or data loss.

#### Acceptance Criteria

1. WHEN the user selects a backup from the list, THE App SHALL display a confirmation dialog warning that the restore will permanently overwrite all current vault data and settings.
2. WHEN the user confirms the restore, THE Restore_Service SHALL download the selected Vault_DB file and Settings_Snapshot JSON file from the AppDataFolder via the Drive_Client.
3. WHEN the download completes, THE Restore_Service SHALL close all open database connections, replace the on-device Vault_DB file with the downloaded file, and write the Settings_Snapshot values back to SharedPreferences.
4. WHEN the restore completes successfully, THE App SHALL restart its data layer (re-open the database and reload settings) and navigate to HomeScreen, discarding the back stack.
5. IF the download fails due to a network or Drive API error, THEN THE Restore_Service SHALL surface an error message to the user and leave the on-device Vault_DB file and SharedPreferences unchanged.
6. WHILE a restore is in progress, THE App SHALL display a progress indicator and prevent the user from initiating a second restore.
7. THE Restore_Service SHALL write the downloaded Vault_DB file to the device filesystem without modifying its contents. After restore, THE Key_Derivation_Service SHALL ensure the Derived_Key for the signed-in account is loaded in the EncryptionService before any vault data is accessed.

---

### Requirement 8: Settings Screen Account Section

**User Story:** As a CredLock user, I want a dedicated Account section in Settings, so that all Google account and backup actions are grouped in one place.

#### Acceptance Criteria

1. THE SettingsScreen SHALL contain an "ACCOUNT" section rendered above the existing "PASSWORD REMINDERS" section.
2. THE Account_Section SHALL display the signed-in user's display name, email address, and profile avatar.
3. THE Account_Section SHALL contain a "Backup to Google Drive" list tile.
4. THE Account_Section SHALL contain a "Restore from Google Drive" list tile.
5. THE Account_Section SHALL contain a "Sign Out" list tile.
6. WHILE a backup or restore operation is in progress, THE Account_Section SHALL disable the "Backup to Google Drive" and "Restore from Google Drive" tiles to prevent concurrent operations.

---

### Requirement 9: Account-Bound Encryption Key Derivation

**User Story:** As a CredLock user, I want my encryption key to be tied to my Google account rather than my device, so that I can restore my vault on a new device without losing access to my encrypted data.

#### Acceptance Criteria

1. WHEN the user signs in with Google for the first time, THE Key_Derivation_Service SHALL derive the AES-256 encryption key using HKDF-SHA256 with the user's stable Google account ID as the input key material and a fixed app-specific salt string `"credlock-v1-key-derivation"`.
2. THE Key_Derivation_Service SHALL produce a 32-byte (256-bit) Derived_Key that is identical for the same Google account ID on any device.
3. WHEN the Derived_Key is produced, THE EncryptionService SHALL use the Derived_Key instead of the previously randomly generated key, storing it in `flutter_secure_storage` under the existing `credlock_aes_key` alias.
4. IF a key already exists in `flutter_secure_storage` from a previous random-key installation, THEN THE Key_Derivation_Service SHALL replace it with the Derived_Key on first sign-in, and THE App SHALL re-encrypt all existing password entries using the new Derived_Key.
5. THE Derived_Key SHALL never be transmitted over the network, stored in the backup files, or logged anywhere.
6. WHEN the user signs out and a different Google account signs in, THE Key_Derivation_Service SHALL derive a new Derived_Key for the new account and clear all existing vault data before allowing access.
