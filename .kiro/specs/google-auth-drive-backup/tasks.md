# Implementation Plan: Google Auth & Drive Backup

## Overview

Implement Google Sign-In authentication, account-bound HKDF-SHA256 key derivation, and Google Drive backup/restore for the CredLock Flutter app. The work is broken into six groups: dependencies and platform config → data layer extensions → new services → updated services → UI changes → main.dart wiring.

## Tasks

- [x] 1. Add dependencies and configure Android platform
  - [x] 1.1 Add new packages to `pubspec.yaml`
    - Add `google_sign_in: ^6.2.2`, `googleapis: ^13.2.0`, `googleapis_auth: ^1.6.0`, `crypto: ^3.0.6` under `dependencies`
    - Run `flutter pub get` to resolve
    - _Requirements: 1.2, 9.1_

  - [x] 1.2 Register Google Services plugin in `android/settings.gradle.kts`
    - Add `id("com.google.gms.google-services") version "4.4.2" apply false` to the `plugins {}` block
    - _Requirements: 1.2_

  - [x] 1.3 Apply Google Services plugin and signing config in `android/app/build.gradle.kts`
    - Add `id("com.google.gms.google-services")` to the `plugins {}` block
    - Add a `signingConfigs` block that reads `storeFile`, `storePassword`, `keyAlias`, `keyPassword` from `android/key.properties`
    - Replace the `release` build type's `signingConfig` with the new `release` signing config
    - Confirm `applicationId = "com.credlock.app"` matches `google-services.json` (already set)
    - _Requirements: 1.2_

- [x] 2. Extend data layer
  - [x] 2.1 Add `close()` and `getDatabasePath()` to `DatabaseHelper`
    - Implement `Future<void> close()` that calls `_db?.close()` and sets `_db = null`
    - Implement `Future<String> getDatabasePath()` that returns `join(await getDatabasesPath(), _dbName)`
    - _Requirements: 5.2, 7.3_

  - [x] 2.2 Add `exportToMap()` and `importFromMap()` to `ReminderSettingsRepository`
    - Add `Future<Map<String, dynamic>> exportToMap()` and `Future<void> importFromMap(Map<String, dynamic> map)` to the abstract interface
    - Implement both methods in `SharedPrefsReminderSettingsRepository` using the three existing SharedPreferences keys (`reminder_enabled`, `reminder_frequency`, `reminder_last_notified_date`)
    - `importFromMap` must handle a `null` value for `reminder_last_notified_date` by calling `prefs.remove(_keyLastNotified)`
    - _Requirements: 5.3, 7.3_

  - [ ]* 2.3 Write property test for settings export/import round-trip
    - **Property 4: Settings Export/Import Round-Trip**
    - For any combination of `reminder_enabled` (bool), `reminder_frequency` (valid storage key string), and `reminder_last_notified_date` (ISO-8601 string or null), calling `exportToMap()` after `importFromMap(map)` SHALL return a map equal to the original
    - **Validates: Requirements 5.3, 7.3**

- [x] 3. Implement `EncryptionService.initWithDerivedKey`
  - [x] 3.1 Add `initWithDerivedKey(Uint8List keyBytes)` to `EncryptionService`
    - Assert `keyBytes.length == 32`
    - Construct `Key` and `Encrypter(AES(key, mode: AESMode.cbc))`, set `_ready = true`
    - Persist the key to `flutter_secure_storage` under `_keyAlias` (base64Url encoded) so it survives restarts
    - Keep the existing `init()` method intact for use during migration
    - _Requirements: 9.3_

- [ ] 4. Implement `KeyDerivationService`
  - [ ] 4.1 Create `lib/core/services/key_derivation_service.dart` with HKDF-SHA256 implementation
    - Implement private `_hkdfExtract(Uint8List salt, Uint8List ikm)` using `Hmac(sha256, salt).convert(ikm)`
    - Implement private `_hkdfExpand(Uint8List prk, Uint8List info, int length)` producing 32 bytes via HMAC-SHA256 counter loop
    - Implement `Uint8List deriveKey(String googleId)` with IKM = UTF-8 bytes of `googleId`, salt = UTF-8 bytes of `"credlock-v1-key-derivation"`, info = UTF-8 bytes of `"credlock-aes-256-key"`, output length = 32
    - _Requirements: 9.1, 9.2_

  - [ ]* 4.2 Write property test for key derivation determinism and length
    - **Property 1: Key Derivation Determinism and Length**
    - For any non-empty Google account ID string, `deriveKey(id)` SHALL return exactly 32 bytes and calling it again with the same ID SHALL return a byte-for-byte identical result
    - **Validates: Requirements 9.1, 9.2**

  - [ ]* 4.3 Write property test for key derivation isolation
    - **Property 2: Key Derivation Isolation**
    - For any two distinct Google account ID strings, `deriveKey()` SHALL produce different 32-byte outputs
    - **Validates: Requirements 9.6**

  - [x] 4.4 Implement `initForAccount(String googleId)` with migration logic
    - Read existing key from `flutter_secure_storage` under `credlock_aes_key`
    - Derive the new key via `deriveKey(googleId)`
    - If an existing key is found AND differs from the derived key: init `EncryptionService` with the old key, load all password entries from `DatabaseHelper`, decrypt each `password` and `pin` field, re-encrypt with the new derived key, write updated entries back, store the new key
    - If no existing key or keys match: store the derived key directly
    - Call `EncryptionService.instance.initWithDerivedKey(derivedKeyBytes)` at the end
    - _Requirements: 9.3, 9.4_

  - [ ]* 4.5 Write property test for migration round-trip
    - **Property 3: Migration Round-Trip**
    - For any non-empty list of plaintext password strings, encrypting with a random key, running migration to the HKDF-derived key, then decrypting with the derived key SHALL produce the original plaintexts
    - **Validates: Requirements 9.4**

- [x] 5. Implement `AuthService`
  - [x] 5.1 Create `lib/core/services/auth_service.dart`
    - Implement singleton with `GoogleSignIn` configured with scopes: `email`, `profile`, `https://www.googleapis.com/auth/drive.appdata`
    - Implement `Future<void> init()`: attempt `_googleSignIn.signInSilently()`; if successful, call `KeyDerivationService.instance.initForAccount(account.id)` and set `_currentUser`; catch all errors silently so `isSignedIn` remains false
    - Implement `bool get isSignedIn` and `GoogleSignInAccount? get currentUser` as synchronous getters backed by `_currentUser`
    - Implement `Future<GoogleSignInAccount?> signIn()`: call `_googleSignIn.signIn()`, on success set `_currentUser` and return the account, return null if cancelled
    - Implement `Future<void> signOut()`: call `_googleSignIn.signOut()`, set `_currentUser = null`
    - Implement `Future<AuthClient> getAuthClient()`: obtain `GoogleSignInAuthentication`, construct `AccessCredentials` with `AccessToken('Bearer', ...)` and the `drive.appdata` scope, return `authenticatedClient(http.Client(), credentials)`
    - _Requirements: 1.2, 1.6, 2.4, 4.3_

- [x] 6. Implement `DriveBackupService`
  - [x] 6.1 Create `lib/core/services/drive_backup_service.dart` with `BackupEntry` model
    - Define `BackupEntry` class with fields: `timestamp` (String), `utcDateTime` (DateTime), `dbFileId` (String), `settingsFileId` (String), `displayLabel` (String)
    - Implement `String _formatTimestamp(DateTime utc)` producing `YYYYMMDDTHHmmssZ`
    - Implement `DateTime? _parseTimestamp(String filename)` parsing the timestamp from a backup filename
    - _Requirements: 5.4, 6.2_

  - [ ]* 6.2 Write property test for backup filename timestamp round-trip
    - **Property 5: Backup Filename Timestamp Round-Trip**
    - For any UTC `DateTime` truncated to whole seconds, `_formatTimestamp` then `_parseTimestamp` SHALL return a `DateTime` equal to the original
    - **Validates: Requirements 5.4**

  - [x] 6.3 Implement `backup()` method
    - Obtain `AuthClient` from `AuthService.instance.getAuthClient()` and create `DriveApi`
    - Call `DatabaseHelper.instance.close()`, then `getDatabasePath()`, read the `.db` file bytes
    - Call `ReminderSettingsRepository.instance.exportToMap()`, encode as JSON bytes
    - Upload both files to `appDataFolder` using `driveApi.files.create(...)` with `uploadMedia`; use the same UTC timestamp for both filenames
    - Return the timestamp string on success; throw on Drive API error
    - _Requirements: 5.2, 5.3, 5.4, 5.7, 5.8_

  - [ ]* 6.4 Write property test for backup data integrity
    - **Property 6: Backup Data Integrity**
    - For any byte sequence read from the database file, the bytes passed to the Drive upload call SHALL be identical to the bytes read from the filesystem; and bytes downloaded during restore SHALL be written to the DB path unchanged
    - **Validates: Requirements 5.8, 7.7**

  - [x] 6.5 Implement `listBackups()` method
    - Query `driveApi.files.list` with `q: "name contains 'credlock_backup_' and name contains '.db'"`, `spaces: 'appDataFolder'`, `$fields: 'files(id,name)'`
    - For each `.db` file, find the matching `_settings.json` file by listing with the paired name
    - Parse `utcDateTime` from each filename, build `BackupEntry` list with `displayLabel` formatted as local date/time
    - Return list sorted descending by `utcDateTime`
    - _Requirements: 6.1, 6.2_

  - [ ]* 6.6 Write property test for backup list sort order
    - **Property 7: Backup List Sort Order**
    - For any non-empty list of `BackupEntry` objects with distinct `utcDateTime` values, `listBackups()` SHALL return them ordered newest first (each entry's `utcDateTime` ≥ next entry's `utcDateTime`)
    - **Validates: Requirements 6.1**

  - [x] 6.7 Implement `restore(BackupEntry entry)` method
    - Download the `.db` file bytes and `_settings.json` bytes using `driveApi.files.get(..., downloadOptions: DownloadOptions.fullMedia)` cast to `Media`
    - Call `DatabaseHelper.instance.close()`
    - Write the downloaded `.db` bytes to the path returned by `getDatabasePath()`, replacing the existing file
    - Decode the settings JSON and call `SharedPrefsReminderSettingsRepository.instance.importFromMap(map)`
    - Throw on any error before file replacement so the on-device state is unchanged; surface errors after replacement with a clear message
    - _Requirements: 7.2, 7.3, 7.5, 7.7_

- [x] 7. Checkpoint — Ensure all service tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. Redesign `LoginScreen`
  - [x] 8.1 Replace email/password form with Google Sign-In button
    - Remove `_emailController`, `_passwordController`, and all related widgets
    - Add `bool _loading` state field
    - Implement `_handleSignIn()`: set `_loading = true`, call `AuthService.instance.signIn()`, on success call `KeyDerivationService.instance.initForAccount(account.id)`, then `Navigator.pushReplacement` to `HomeScreen`; on null (cancelled) reset `_loading`; on error show `SnackBar` with the error message and reset `_loading`
    - Render a "Sign in with Google" `ElevatedButton` with a Google logo icon when `_loading` is false; render `CircularProgressIndicator` when `_loading` is true
    - Keep the existing logo, app name, and orange blob background
    - _Requirements: 1.1, 1.3, 1.4, 1.5_

- [x] 9. Update `SplashScreen` routing
  - [x] 9.1 Replace unconditional `HomeScreen` navigation with auth-aware routing
    - After `_exitController.forward()` completes, check `AuthService.instance.isSignedIn`
    - If `true`: navigate to `HomeScreen` (existing behaviour)
    - If `false`: navigate to `LoginScreen`
    - No additional async call needed — `isSignedIn` is synchronous
    - _Requirements: 2.1, 2.2, 2.3, 2.4_

- [x] 10. Add Account section to `SettingsScreen`
  - [x] 10.1 Build `_AccountSection` widget
    - Read `AuthService.instance.currentUser` for `displayName`, `email`, `photoUrl`
    - Render a `CircleAvatar` with `NetworkImage(photoUrl)` if available; fall back to initials text on null or load error
    - Display `displayName` and `email` in a `ListTile`-style header row
    - _Requirements: 3.2, 3.3, 3.4, 8.2_

  - [ ]* 10.2 Write property test for account section profile display
    - **Property 8: Account Section Displays User Profile**
    - For any `GoogleSignInAccount` with non-null `displayName` and `email`, rendering the Account section widget SHALL produce a widget tree containing both strings as visible text
    - **Validates: Requirements 3.2, 8.2**

  - [x] 10.3 Implement Backup tile with progress state
    - Add `bool _backupInProgress` and `bool _restoreInProgress` state fields to `_SettingsScreenState`
    - Add a `ListTile` for "Backup to Google Drive" that is disabled when `_backupInProgress || _restoreInProgress`
    - On tap: set `_backupInProgress = true`, call `DriveBackupService.instance.backup()`, show success `SnackBar` with the returned timestamp, reset `_backupInProgress`; on error show error `SnackBar`
    - Show `CircularProgressIndicator` in the tile trailing while `_backupInProgress` is true
    - _Requirements: 5.1, 5.5, 5.6, 5.7, 8.3, 8.6_

  - [x] 10.4 Implement Restore tile with bottom sheet and confirmation dialog
    - Add a `ListTile` for "Restore from Google Drive" that is disabled when `_backupInProgress || _restoreInProgress`
    - On tap: show a `DraggableScrollableSheet` bottom sheet that calls `DriveBackupService.instance.listBackups()` and displays entries; show loading indicator while fetching; show "No backups available" if list is empty; show error with retry on failure
    - On entry tap: show `AlertDialog` warning that restore will overwrite all current data; on confirm set `_restoreInProgress = true`, call `DriveBackupService.instance.restore(entry)`, then navigate to `HomeScreen` with `pushAndRemoveUntil`; on error show error `SnackBar` and reset `_restoreInProgress`
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 7.1, 7.2, 7.4, 7.6, 8.4, 8.6_

  - [x] 10.5 Implement Sign Out tile with confirmation dialog
    - Add a `ListTile` for "Sign Out"
    - On tap: show `AlertDialog` asking for confirmation; on confirm call `AuthService.instance.signOut()`, then `Navigator.pushAndRemoveUntil` to `LoginScreen`; on dismiss stay on `SettingsScreen`
    - Disable the tile while `_backupInProgress || _restoreInProgress`
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

  - [x] 10.6 Insert `_AccountSection` above `PASSWORD REMINDERS` in `SettingsScreen`
    - Add the `_AccountSection` widget as the first item in the `ListView` children, above the existing `PASSWORD REMINDERS` section
    - _Requirements: 8.1_

- [x] 11. Update `main.dart`
  - [x] 11.1 Replace `EncryptionService.instance.init()` with `AuthService.instance.init()`
    - Remove the `await EncryptionService.instance.init()` call
    - Add `await AuthService.instance.init()` before the `Workmanager` and `NotificationService` calls
    - Add the `AuthService` import; remove the now-unused direct `EncryptionService` import if no longer needed in `main.dart`
    - _Requirements: 2.1, 9.3_

- [x] 12. Final checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Each task references specific requirements for traceability
- Property tests use `package:test` with manual generators or a Dart PBT library such as `glados`
- The `BackupEntry` model is defined in the same file as `DriveBackupService`
- The `applicationId` in `android/app/build.gradle.kts` is already set to `com.credlock.app`, matching `google-services.json` — no change needed there
- `AuthService.init()` silently catches all errors so a stale or revoked session never crashes startup
- `EncryptionService.init()` (random key path) is kept intact; it is only called internally by `KeyDerivationService` during migration
