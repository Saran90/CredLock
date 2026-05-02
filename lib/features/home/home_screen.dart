import 'package:flutter/material.dart';
import '../../core/services/reminder_service.dart';
import '../../core/theme/app_colors.dart';
import '../settings/settings_screen.dart';
import '../vault/vault_screen.dart';
import '../create/create_password_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final _vaultKey = GlobalKey<VaultScreenState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          VaultScreen(key: _vaultKey),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
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
        onTap: (i) async {
          // Centre button (index 1) opens create screen as a modal
          if (i == 1) {
            final saved = await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => const CreatePasswordScreen()),
            );
            if (saved == true) _vaultKey.currentState?.reload();
            return;
          }
          // Index 0 → Vault, index 2 → Settings (map to stack index 0 or 1)
          setState(() => _currentIndex = i == 0 ? 0 : 1);
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.lock_outline),
            activeIcon: Icon(Icons.lock),
            label: 'Vault',
          ),
          BottomNavigationBarItem(
            icon: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.black, size: 26),
            ),
            label: '',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
