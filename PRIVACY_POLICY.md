# Privacy Policy for CredLock

**Last Updated:** June 3, 2026

## Introduction

CredLock ("we", "our", or "the app") is a password management application designed to help you securely store and manage your passwords and credentials. This Privacy Policy explains how we collect, use, store, and protect your information.

## Information We Collect

### 1. Google Account Information
When you sign in with Google, we collect:
- Your Google account ID
- Email address
- Display name
- Profile photo URL

**Purpose:** To authenticate your identity, derive encryption keys, and enable cloud backup functionality.

### 2. Password Vault Data
You create and store the following information in the app:
- Website/app names and URLs
- Usernames
- Passwords
- PINs
- Notes and metadata
- Password creation dates
- App package names (for autofill functionality)

**Purpose:** To provide the core password management functionality.

### 3. Biometric Data
If you enable biometric authentication:
- The app requests access to your device's biometric sensors (fingerprint, face recognition)
- Biometric data **never leaves your device** and is processed entirely by your device's secure hardware
- We only receive a success/failure result from the authentication attempt

**Purpose:** To provide secure, convenient access to your vault.

### 4. Device Credentials
If biometric authentication is unavailable, the app may use:
- Device PIN, pattern, or password (processed by your device's OS)

**Purpose:** To provide fallback authentication when biometrics are not available.

### 5. Notification Permissions
If you enable password change reminders:
- The app schedules local notifications on your device
- No notification content is transmitted to external servers

**Purpose:** To remind you to update old passwords.

### 6. Usage Data
The app stores locally:
- Your reminder frequency preferences
- Biometric authentication enabled/disabled setting
- Last backup timestamp

**Purpose:** To maintain your app settings and preferences.

## How We Use Your Information

### Encryption
- All passwords, usernames, PINs, URLs, and notes are encrypted using **AES-256 encryption**
- The encryption key is **deterministically derived** from your Google account ID using HKDF-SHA256
- Your vault data is encrypted **before** being stored on your device
- The encryption key is stored in your device's secure storage (Android KeyStore / iOS Keychain)

### Local Storage
- All vault data is stored **locally on your device** in an encrypted SQLite database
- No password data is transmitted to any server except Google Drive (when you explicitly trigger a backup)

### Google Drive Backup (Optional)
When you choose to back up your vault:
- The **encrypted** vault database is uploaded to your Google Drive App Data folder
- This folder is private to CredLock and not accessible to other apps or users
- The backup file contains encrypted data; even Google cannot decrypt it
- You can restore your vault from any device by signing in with the same Google account

### Authentication
- Your Google account ID is used to derive the encryption key using a one-way cryptographic function
- The same Google account always produces the same encryption key, enabling cross-device vault access
- We never store or transmit your actual passwords in plaintext

## Data Sharing and Disclosure

**We do not sell, trade, or share your data with third parties.** Specifically:

- **No Analytics:** We do not use analytics services
- **No Advertising:** We do not display ads or share data with advertisers
- **No Third-Party Services:** Except for Google Sign-In and Google Drive (which you explicitly authorize), no data is transmitted to external services

### Google Services
The app uses:
1. **Google Sign-In:** For authentication (governed by [Google's Privacy Policy](https://policies.google.com/privacy))
2. **Google Drive API:** For optional encrypted backups (governed by [Google's Privacy Policy](https://policies.google.com/privacy))

We request the following Google API scopes:
- `email` — to identify your account
- `profile` — to display your name and photo
- `https://www.googleapis.com/auth/drive.appdata` — to store encrypted backups in your private App Data folder

## Data Security

### Encryption
- AES-256 encryption with unique initialization vectors (IVs) for each field
- HKDF-SHA256 key derivation from your Google account ID
- Secure key storage using platform-specific secure storage APIs

### Device Security
- Biometric authentication (fingerprint, face) or device PIN/pattern/password
- Keys are stored in Android KeyStore or iOS Keychain (hardware-backed when available)

### No Cloud Storage of Plaintext
- Your passwords are **never** stored or transmitted in plaintext
- Even our developers cannot access your vault data

## Data Retention

### On Your Device
- Vault data remains on your device until you explicitly delete it or uninstall the app
- You can delete individual passwords or clear your entire vault at any time

### Google Drive Backups
- Backups remain in your Google Drive App Data folder until you delete them
- You can manage backups through the app's Restore interface
- Uninstalling the app does **not** automatically delete Google Drive backups

### Account Deletion
When you sign out and disconnect your account:
- Your local vault data is **not** automatically deleted (it remains encrypted on your device)
- Google Drive backups remain in your Google Drive (you can delete them manually)
- To fully remove all data:
  1. Sign out from the app
  2. Uninstall the app (removes local data)
  3. Delete backup files from Google Drive (via the app or Google Drive settings)

## Your Rights and Choices

You have the right to:

1. **Access Your Data:** All your vault data is accessible within the app
2. **Export Your Data:** You can view and copy any stored password
3. **Delete Your Data:** You can delete individual entries or sign out and uninstall the app
4. **Control Backups:** You can choose whether to back up to Google Drive
5. **Disable Biometric Auth:** You can toggle biometric authentication on/off in Settings
6. **Revoke Access:** You can disconnect your Google account, which revokes the app's access to Google Drive

## Children's Privacy

CredLock is not intended for users under the age of 13. We do not knowingly collect personal information from children under 13. If you believe a child under 13 has provided us with personal information, please contact us, and we will delete such information.

## Changes to This Privacy Policy

We may update this Privacy Policy from time to time. When we do:
- The "Last Updated" date at the top will be revised
- Significant changes will be communicated through the app or via email (if we have your contact information)
- Continued use of the app after changes constitutes acceptance of the updated policy

## Open Source

CredLock is open-source software. You can review the source code to verify our privacy and security claims at:
[https://github.com/Saran90/CredLock](https://github.com/Saran90/CredLock)

## Contact Us

If you have questions, concerns, or requests regarding this Privacy Policy or your data, please contact us at:

**Email:** [Your contact email]  
**GitHub Issues:** [https://github.com/Saran90/CredLock/issues](https://github.com/Saran90/CredLock/issues)

## Legal Basis for Processing (GDPR)

For users in the European Economic Area (EEA), our legal basis for processing your personal information includes:

- **Consent:** You provide consent when you sign in with Google and authorize access to your account information and Google Drive
- **Legitimate Interest:** We have a legitimate interest in providing secure password management functionality
- **Contractual Necessity:** Processing is necessary to provide the service you requested

## Your GDPR Rights

If you are in the EEA, you have the right to:
- Access your personal data
- Rectify inaccurate data
- Erase your data ("right to be forgotten")
- Restrict processing
- Data portability
- Object to processing
- Lodge a complaint with your local data protection authority

## California Privacy Rights (CCPA)

If you are a California resident, you have the right to:
- Know what personal information we collect, use, and disclose
- Request deletion of your personal information
- Opt-out of the sale of personal information (note: we do not sell personal information)
- Non-discrimination for exercising your privacy rights

## Technical Details

### Data Flow
1. You sign in with Google → Google account ID is obtained
2. Encryption key is derived from your Google account ID (deterministic, one-way)
3. You create/edit passwords → Data is encrypted with AES-256
4. Encrypted data is stored in local SQLite database
5. (Optional) You trigger backup → Encrypted database is uploaded to your Google Drive App Data folder

### What We Can See
- We can see: Public information from your Google profile (name, email, photo)
- We **cannot** see: Your passwords, PINs, or any decrypted vault content

### Third-Party Access
- **Google:** Has access to your Google Drive backups (but cannot decrypt them)
- **Device Manufacturer:** May have access to biometric data (handled by device OS, not transmitted to us)
- **No one else:** Your vault data is encrypted and private

## Compliance

This app strives to comply with:
- General Data Protection Regulation (GDPR)
- California Consumer Privacy Act (CCPA)
- Google API Services User Data Policy
- Android and iOS platform privacy requirements

---

**By using CredLock, you acknowledge that you have read and understood this Privacy Policy and agree to its terms.**
