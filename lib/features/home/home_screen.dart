import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/reminder_service.dart';
import '../../core/services/update_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../health/health_dashboard_screen.dart';
import '../settings/settings_screen.dart';
import '../vault/vault_screen.dart';
import '../create/create_password_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // 0 = Vault, 1 = Health, 2 = Settings
  int _currentIndex = 0;
  final _vaultKey = GlobalKey<VaultScreenState>();

  // Soft-update banner state
  UpdateInfo? _updateInfo;
  bool _bannerDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _consumePendingUpdate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ReminderService.instance.performForegroundCheck();
    }
  }

  /// Reads the UpdateInfo that SplashScreen stored after its version check.
  /// Only shows the banner if it is a soft update and the user hasn't already
  /// dismissed it for this version.
  Future<void> _consumePendingUpdate() async {
    final info = UpdateService.pendingInfo;
    UpdateService.pendingInfo =
        null; // consume — don't show again on hot reload

    if (info == null || info.status != UpdateStatus.softUpdate) return;

    final alreadyDismissed = await UpdateService.instance.isDismissed(
      info.latestVersion,
    );
    if (!mounted) return;
    if (!alreadyDismissed) {
      setState(() => _updateInfo = info);
    }
  }

  Future<void> _dismissBanner() async {
    if (_updateInfo != null) {
      await UpdateService.instance.dismissSoftUpdate(
        _updateInfo!.latestVersion,
      );
    }
    if (!mounted) return;
    setState(() => _bannerDismissed = true);
  }

  Future<void> _openStore(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openCreate() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreatePasswordScreen()),
    );
    if (saved == true) _vaultKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final showBanner = _updateInfo != null && !_bannerDismissed;

    return Scaffold(
      body: Column(
        children: [
          // ── Soft-update banner ──────────────────────────────────────────
          if (showBanner)
            _UpdateBanner(
              info: _updateInfo!,
              onUpdate: () => _openStore(_updateInfo!.updateUrl),
              onDismiss: _dismissBanner,
            ),

          // ── Main tab content ────────────────────────────────────────────
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                VaultScreen(key: _vaultKey),
                const HealthDashboardScreen(),
                const SettingsScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildFab() {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x55FF8C00),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _openCreate,
          child: const Icon(Icons.add, color: Colors.black, size: 28),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.lock_outline),
            activeIcon: Icon(Icons.lock),
            label: 'Vault',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.health_and_safety_outlined),
            activeIcon: Icon(Icons.health_and_safety),
            label: 'Health',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// ── Soft-update banner ────────────────────────────────────────────────────────

class _UpdateBanner extends StatelessWidget {
  final UpdateInfo info;
  final VoidCallback onUpdate;
  final VoidCallback onDismiss;

  const _UpdateBanner({
    required this.info,
    required this.onUpdate,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // Respect system status bar height
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(16, topPadding + 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          bottom: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.system_update_outlined,
              color: Colors.black,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Update available — v${info.latestVersion}',
                  style: AppTextStyles.titleMedium.copyWith(fontSize: 13),
                ),
                if (info.releaseNotes.isNotEmpty)
                  Text(
                    info.releaseNotes,
                    style: AppTextStyles.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Update button
          TextButton(
            onPressed: onUpdate,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'UPDATE',
              style: AppTextStyles.buttonText.copyWith(fontSize: 12),
            ),
          ),

          // Dismiss button
          GestureDetector(
            onTap: onDismiss,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.close, size: 16, color: AppColors.textHint),
            ),
          ),
        ],
      ),
    );
  }
}
