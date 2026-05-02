import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/services/reminder_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/password_entry.dart';
import '../../data/repositories/password_repository.dart';
import '../../data/repositories/reminder_settings_repository.dart';
import '../create/create_password_screen.dart';
import 'vault_detail_screen.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

// Public alias so HomeScreen can hold a typed GlobalKey
typedef VaultScreenState = _VaultScreenState;

class _VaultScreenState extends State<VaultScreen> {
  List<PasswordEntry> _entries = [];
  List<PasswordEntry> _filtered = [];
  List<PasswordEntry> _overdueEntries = [];
  bool _bannerDismissed = false;
  bool _loading = true;
  bool _searching = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Called externally (e.g. from HomeScreen) to refresh the list.
  Future<void> reload() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await PasswordRepository.instance.getAll();

    // Check for overdue entries if reminders are enabled
    final settings = await SharedPrefsReminderSettingsRepository.instance
        .getSettings();
    List<PasswordEntry> overdue = [];
    if (settings.enabled) {
      final now = DateTime.now();
      overdue = entries
          .where((e) => isOverdue(e, settings.frequency, now))
          .toList();
    }

    if (!mounted) return;
    setState(() {
      _entries = entries;
      _filtered = entries;
      _overdueEntries = overdue;
      _bannerDismissed = false;
      _loading = false;
    });
  }

  void _onSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _filtered = _entries);
      return;
    }
    final results = await PasswordRepository.instance.search(query);
    setState(() => _filtered = results);
  }

  Future<void> _openCreate() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreatePasswordScreen()),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(PasswordEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Delete entry?', style: AppTextStyles.titleLarge),
        content: Text(
          'Remove "${entry.name}" from your vault?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirm == true && entry.id != null) {
      await PasswordRepository.instance.delete(entry.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: AppTextStyles.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'Search vault...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onChanged: _onSearch,
              )
            : const Text('credlock'),
        actions: [
          IconButton(
            icon: Icon(
              _searching ? Icons.close : Icons.search,
              color: AppColors.textSecondary,
            ),
            onPressed: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) {
                  _searchController.clear();
                  _filtered = _entries;
                }
              });
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _filtered.isEmpty
          ? _buildEmpty()
          : _buildList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline,
              color: AppColors.textHint,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _searching ? 'No results found' : 'Your vault is empty',
            style: AppTextStyles.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            _searching
                ? 'Try a different search term'
                : 'Tap + to add your first password',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    // Group by category
    final websites = _filtered.where((e) => e.category == 'website').toList();
    final mobile = _filtered.where((e) => e.category == 'mobile').toList();
    final overdueIds = _overdueEntries.map((e) => e.id).toSet();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        // ── Overdue reminder banner ──────────────────────────────────────
        if (_overdueEntries.isNotEmpty && !_bannerDismissed) ...[
          _OverdueBanner(
            overdueEntries: _overdueEntries,
            onDismiss: () => setState(() => _bannerDismissed = true),
            onEntryTap: (entry) async {
              final saved = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => CreatePasswordScreen(entry: entry),
                ),
              );
              if (saved == true) _load();
            },
          ),
          const SizedBox(height: 16),
        ],
        if (websites.isNotEmpty) ...[
          _sectionLabel('WEBSITES', Icons.language),
          const SizedBox(height: 10),
          ...websites.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _VaultItem(
                entry: e,
                isOverdue: overdueIds.contains(e.id),
                onDelete: () => _delete(e),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (mobile.isNotEmpty) ...[
          _sectionLabel('MOBILE APPS', Icons.smartphone),
          const SizedBox(height: 10),
          ...mobile.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _VaultItem(
                entry: e,
                isOverdue: overdueIds.contains(e.id),
                onDelete: () => _delete(e),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.textHint),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.labelSmall),
      ],
    );
  }
}

// ── Overdue reminder banner ───────────────────────────────────────────────────

class _OverdueBanner extends StatelessWidget {
  final List<PasswordEntry> overdueEntries;
  final VoidCallback onDismiss;
  final ValueChanged<PasswordEntry> onEntryTap;

  const _OverdueBanner({
    required this.overdueEntries,
    required this.onDismiss,
    required this.onEntryTap,
  });

  @override
  Widget build(BuildContext context) {
    final count = overdueEntries.length;
    final headline = count == 1
        ? '1 password needs updating'
        : '$count passwords need updating';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    headline,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.primary,
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Dismiss',
                ),
              ],
            ),
          ),
          // Entry rows
          ...overdueEntries.map(
            (entry) => InkWell(
              onTap: () => onEntryTap(entry),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_clock_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.name,
                        style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'Update',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Vault item ────────────────────────────────────────────────────────────────

class _VaultItem extends StatelessWidget {
  final PasswordEntry entry;
  final bool isOverdue;
  final VoidCallback onDelete;

  const _VaultItem({
    required this.entry,
    required this.isOverdue,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isWebsite = entry.category == 'website';

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false; // let _delete handle the actual removal + reload
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      child: GestureDetector(
        onTap: () {
          final vaultState = context
              .findAncestorStateOfType<_VaultScreenState>();
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (_) => VaultDetailScreen(entry: entry),
                ),
              )
              .then((saved) {
                if (saved == true) {
                  // Entry was edited — reload the vault list
                  vaultState?._load();
                }
              });
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: entry.appIconBase64 != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          base64Decode(entry.appIconBase64!),
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(
                        isWebsite ? Icons.language : Icons.smartphone,
                        color: AppColors.primary,
                        size: 20,
                      ),
              ),
              const SizedBox(width: 12),

              // Name + username
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.name, style: AppTextStyles.titleMedium),
                    if (entry.username.isNotEmpty || entry.url.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        entry.username.isNotEmpty ? entry.username : entry.url,
                        style: AppTextStyles.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // PIN badge
              if (entry.pin != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Icon(
                    Icons.pin_outlined,
                    color: AppColors.primary,
                    size: 12,
                  ),
                ),
                const SizedBox(width: 6),
              ],

              // Overdue badge
              if (isOverdue) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Icon(
                    Icons.schedule,
                    color: Colors.orange,
                    size: 12,
                  ),
                ),
                const SizedBox(width: 6),
              ],

              // Category badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isWebsite ? 'Website' : 'App',
                  style: AppTextStyles.labelSmall.copyWith(fontSize: 10),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textHint,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
