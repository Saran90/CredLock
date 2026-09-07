# CredLock v1.2.0 — Release Notes

## What's New

### Custom Tags
Organise your vault your way. Create your own labels — Work, Banking, Family, or anything you like — and assign them to any credential. A filter bar at the top of the vault lets you instantly narrow down entries by tag. Manage your tags from Settings → Vault → Manage Tags.

### Update Notifications
The app will now notify you when a new version is available. A banner appears at the top of the screen with a direct link to the Play Store. You can dismiss it and it won't appear again until the next release.

### About Section in Settings
Settings now shows your current app version and a Check for Updates option so you can manually check for new releases at any time.

## Improvements
- Health meter now correctly handles credentials that use a PIN instead of a password. PIN-only entries are no longer flagged as unhealthy.
- Overdue password check skips PIN-only entries, since there is no password to rotate.

## Bug Fixes
- Fixed: items with only an app PIN set were incorrectly marked as unhealthy in the Security Health dashboard.

---
*CredLock v1.2.0 (build 4)*

---

# CredLock v1.1.0 — Release Notes

## What's New

### Security Health Dashboard
Get a clear picture of your vault's security at a glance. The new Health tab shows your overall security score (0–100) with a live score ring, and breaks down any issues into four categories — weak passwords, reused passwords, overdue updates, and entries with no password. Tap any issue to see the affected entries and fix them directly.

### Favorites
Star any credential to pin it to the top of your vault. Your most-used logins are now always one tap away, no scrolling needed. Toggle the star from the vault list or from inside the credential detail screen.

### Clipboard Auto-Clear
Copied passwords are automatically wiped from your clipboard after a set time. Choose from 15, 30, or 60 seconds — or turn it off entirely — in Settings. A snackbar shows the countdown and lets you clear immediately if needed.

### Delete Credential from Detail Screen
You can now delete a credential directly from its detail screen using the delete icon in the top bar. A confirmation prompt prevents accidental deletions.

## Improvements
- Vault screen title corrected to "CredLock"
- The Add (+) button is now a floating action button, keeping the bottom navigation clean and consistent across all screens
- Bottom navigation updated with a dedicated Health tab (Vault · Health · Settings)

## Bug Fixes
- None in this release

---
*CredLock v1.1.0 (build 3)*
