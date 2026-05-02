import 'package:flutter/material.dart';
import '../../core/models/reminder_frequency.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/drive_backup_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/reminder_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/repositories/reminder_settings_repository.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _enabled = false;
  ReminderFrequency _frequency = ReminderFrequency.oneMonth;
  bool _permissionDenied = false;
  bool _loading = true;

  // Account section progress state
  bool _backupInProgress = false;
  bool _restoreInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await SharedPrefsReminderSettingsRepository.instance
        .getSettings();
    final hasPermission = await NotificationService.instance.hasPermission();

    if (!mounted) return;
    setState(() {
      _enabled = settings.enabled;
      _frequency = settings.frequency;
      _permissionDenied = settings.enabled && !hasPermission;
      _loading = false;
    });
  }

  Future<void> _onToggleChanged(bool value) async {
    await SharedPrefsReminderSettingsRepository.instance.setEnabled(value);

    if (value) {
      final granted = await NotificationService.instance.requestPermission();
      if (granted) {
        await ReminderService.instance.init();
        if (!mounted) return;
        setState(() {
          _enabled = true;
          _permissionDenied = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _enabled = true;
          _permissionDenied = true;
        });
      }
    } else {
      await NotificationService.instance.cancelReminderNotification();
      await ReminderService.instance.cancelSchedule();
      if (!mounted) return;
      setState(() {
        _enabled = false;
        _permissionDenied = false;
      });
    }
  }

  Future<void> _onFrequencyChanged(ReminderFrequency frequency) async {
    await SharedPrefsReminderSettingsRepository.instance.setFrequency(
      frequency,
    );
    if (!mounted) return;
    setState(() {
      _frequency = frequency;
    });
  }

  // ── Backup ─────────────────────────────────────────────────────────────────

  Future<void> _handleBackup() async {
    setState(() => _backupInProgress = true);
    try {
      final timestamp = await DriveBackupService.instance.backup();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Backup successful: $timestamp')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    } finally {
      if (mounted) setState(() => _backupInProgress = false);
    }
  }

  // ── Restore ────────────────────────────────────────────────────────────────

  Future<void> _handleRestore() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RestoreBottomSheet(
        onEntrySelected: (entry) async {
          Navigator.of(ctx).pop();
          await _confirmAndRestore(entry);
        },
      ),
    );
  }

  Future<void> _confirmAndRestore(BackupEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup'),
        content: const Text(
          'This will permanently overwrite all current vault data and settings. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _restoreInProgress = true);
    try {
      await DriveBackupService.instance.restore(entry);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      setState(() => _restoreInProgress = false);
    }
  }

  // ── Sign Out ───────────────────────────────────────────────────────────────

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await AuthService.instance.disconnect();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: AppTextStyles.appBarTitle),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // ── ACCOUNT section ──────────────────────────────────────────
                _AccountSection(
                  backupInProgress: _backupInProgress,
                  restoreInProgress: _restoreInProgress,
                  onBackup: _handleBackup,
                  onRestore: _handleRestore,
                  onSignOut: _handleSignOut,
                ),

                // ── PASSWORD REMINDERS section ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PASSWORD REMINDERS',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                              title: Text(
                                'Password Change Reminder',
                                style: AppTextStyles.titleMedium,
                              ),
                              subtitle: Text(
                                'Get notified when passwords are due for a change',
                                style: AppTextStyles.bodySmall,
                              ),
                              value: _enabled,
                              onChanged: _onToggleChanged,
                            ),
                            if (_enabled) ...[
                              Divider(
                                color: AppColors.divider,
                                height: 1,
                                thickness: 1,
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  16,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Remind me every',
                                      style: AppTextStyles.bodySmall,
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: ReminderFrequency.values
                                          .map(
                                            (frequency) => ChoiceChip(
                                              label: Text(frequency.label),
                                              selected: _frequency == frequency,
                                              selectedColor: AppColors.primary,
                                              backgroundColor:
                                                  AppColors.surface,
                                              checkmarkColor: Colors.white,
                                              labelStyle: TextStyle(
                                                color: _frequency == frequency
                                                    ? Colors.white
                                                    : AppColors.textSecondary,
                                                fontWeight:
                                                    _frequency == frequency
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                              ),
                                              onSelected: (selected) =>
                                                  _onFrequencyChanged(
                                                    frequency,
                                                  ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_permissionDenied && _enabled) ...[
                        const SizedBox(height: 12),
                        _PermissionWarningBanner(
                          onOpenSettings: () => _showOpenSettingsSnackBar(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _showOpenSettingsSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'To enable notifications, go to Settings > Apps > CredLock > Notifications.',
        ),
        duration: Duration(seconds: 6),
      ),
    );
  }
}

// ── _AccountSection ──────────────────────────────────────────────────────────

class _AccountSection extends StatelessWidget {
  const _AccountSection({
    required this.backupInProgress,
    required this.restoreInProgress,
    required this.onBackup,
    required this.onRestore,
    required this.onSignOut,
  });

  final bool backupInProgress;
  final bool restoreInProgress;
  final VoidCallback onBackup;
  final VoidCallback onRestore;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final bool operationInProgress = backupInProgress || restoreInProgress;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACCOUNT',
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // ── Profile header row ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      _UserAvatar(
                        photoUrl: user?.photoUrl,
                        displayName: user?.displayName,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.displayName ?? '',
                              style: AppTextStyles.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              user?.email ?? '',
                              style: AppTextStyles.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(color: AppColors.divider, height: 1, thickness: 1),

                // ── Backup tile ─────────────────────────────────────────────
                ListTile(
                  enabled: !operationInProgress,
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: Text(
                    'Backup to Google Drive',
                    style: AppTextStyles.titleMedium,
                  ),
                  trailing: backupInProgress
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: operationInProgress ? null : onBackup,
                ),

                Divider(color: AppColors.divider, height: 1, thickness: 1),

                // ── Restore tile ────────────────────────────────────────────
                ListTile(
                  enabled: !operationInProgress,
                  leading: const Icon(Icons.cloud_download_outlined),
                  title: Text(
                    'Restore from Google Drive',
                    style: AppTextStyles.titleMedium,
                  ),
                  trailing: restoreInProgress
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: operationInProgress ? null : onRestore,
                ),

                Divider(color: AppColors.divider, height: 1, thickness: 1),

                // ── Sign Out tile ───────────────────────────────────────────
                ListTile(
                  enabled: !operationInProgress,
                  leading: const Icon(Icons.logout),
                  title: Text('Sign Out', style: AppTextStyles.titleMedium),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: operationInProgress ? null : onSignOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── _UserAvatar ──────────────────────────────────────────────────────────────

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({this.photoUrl, this.displayName});

  final String? photoUrl;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final initials = (displayName != null && displayName!.isNotEmpty)
        ? displayName![0].toUpperCase()
        : '?';

    if (photoUrl != null) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.primary,
        foregroundImage: NetworkImage(photoUrl!),
        onForegroundImageError: (_, _) {},
        child: Text(initials, style: const TextStyle(color: Colors.white)),
      );
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.primary,
      child: Text(initials, style: const TextStyle(color: Colors.white)),
    );
  }
}

// ── _RestoreBottomSheet ──────────────────────────────────────────────────────

class _RestoreBottomSheet extends StatefulWidget {
  const _RestoreBottomSheet({required this.onEntrySelected});

  final void Function(BackupEntry entry) onEntrySelected;

  @override
  State<_RestoreBottomSheet> createState() => _RestoreBottomSheetState();
}

class _RestoreBottomSheetState extends State<_RestoreBottomSheet> {
  late Future<List<BackupEntry>> _backupsFuture;

  @override
  void initState() {
    super.initState();
    _backupsFuture = DriveBackupService.instance.listBackups();
  }

  void _retry() {
    setState(() {
      _backupsFuture = DriveBackupService.instance.listBackups();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle bar
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Restore from Google Drive',
                  style: AppTextStyles.titleMedium,
                ),
              ),
              Divider(color: AppColors.divider, height: 1, thickness: 1),
              Expanded(
                child: FutureBuilder<List<BackupEntry>>(
                  future: _backupsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Failed to load backups: ${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodySmall,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _retry,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final entries = snapshot.data ?? [];
                    if (entries.isEmpty) {
                      return Center(
                        child: Text(
                          'No backups available',
                          style: AppTextStyles.bodySmall,
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => Divider(
                        color: AppColors.divider,
                        height: 1,
                        thickness: 1,
                      ),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return ListTile(
                          title: Text(
                            entry.displayLabel,
                            style: AppTextStyles.titleMedium,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => widget.onEntrySelected(entry),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── _PermissionWarningBanner ─────────────────────────────────────────────────

class _PermissionWarningBanner extends StatelessWidget {
  const _PermissionWarningBanner({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade700),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Notifications are required for reminders to work.',
              style: AppTextStyles.bodySmall,
            ),
          ),
          TextButton(
            onPressed: onOpenSettings,
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
