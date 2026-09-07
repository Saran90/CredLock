import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/services/reminder_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/password_entry.dart';
import '../../data/models/tag.dart';
import '../../data/repositories/password_repository.dart';
import '../../data/repositories/reminder_settings_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../create/create_password_screen.dart';
import '../tags/tag_management_screen.dart';
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

  // Tags
  List<Tag> _allTags = [];
  int? _activeTagFilter; // null = "All"

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

    final results = await Future.wait([
      PasswordRepository.instance.getAll(),
      TagRepository.instance.getAll(),
      SharedPrefsReminderSettingsRepository.instance.getSettings(),
    ]);

    final entries = results[0] as List<PasswordEntry>;
    final tags = results[1] as List<Tag>;
    final settings = results[2] as dynamic;

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
      _allTags = tags;
      _filtered = _applyTagFilter(entries, _activeTagFilter);
      _overdueEntries = overdue;
      _bannerDismissed = false;
      _loading = false;
    });
  }

  List<PasswordEntry> _applyTagFilter(List<PasswordEntry> entries, int? tagId) {
    if (tagId == null) return entries;
    return entries.where((e) => e.tagIds.contains(tagId)).toList();
  }

  void _onSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _filtered = _applyTagFilter(_entries, _activeTagFilter));
      return;
    }
    final results = await PasswordRepository.instance.search(query);
    setState(() => _filtered = _applyTagFilter(results, _activeTagFilter));
  }

  void _setTagFilter(int? tagId) {
    setState(() {
      _activeTagFilter = tagId;
      _filtered = _applyTagFilter(_entries, tagId);
      // Also re-apply any live search text
      final q = _searchController.text;
      if (q.isNotEmpty) _onSearch(q);
    });
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

  Future<void> _toggleFavorite(PasswordEntry entry) async {
    final updated = await PasswordRepository.instance.toggleFavorite(entry);
    setState(() {
      _entries = _entries.map((e) => e.id == updated.id ? updated : e).toList();
      _filtered = _filtered
          .map((e) => e.id == updated.id ? updated : e)
          .toList();
    });
  }

  Future<void> _openTagManagement() async {
    final mutated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TagManagementScreen()),
    );
    if (mutated == true) _load();
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
            : const Text('CredLock'),
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
                  _filtered = _applyTagFilter(_entries, _activeTagFilter);
                }
              });
            },
          ),
          // Tag management button
          IconButton(
            icon: const Icon(
              Icons.label_outline,
              color: AppColors.textSecondary,
            ),
            tooltip: 'Manage tags',
            onPressed: _openTagManagement,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              children: [
                // ── Tag filter bar ─────────────────────────────────────
                if (_allTags.isNotEmpty)
                  _TagFilterBar(
                    tags: _allTags,
                    activeTagId: _activeTagFilter,
                    onSelect: _setTagFilter,
                  ),
                Expanded(
                  child: _filtered.isEmpty ? _buildEmpty() : _buildList(),
                ),
              ],
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
            _searching
                ? 'No results found'
                : _activeTagFilter != null
                ? 'No entries with this tag'
                : 'Your vault is empty',
            style: AppTextStyles.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            _searching
                ? 'Try a different search term'
                : _activeTagFilter != null
                ? 'Add a tag to an entry while editing it'
                : 'Tap + to add your first password',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    // Build a fast id→Tag lookup for rendering chips on each entry.
    final tagById = {for (final t in _allTags) t.id!: t};

    // Group by category (existing behaviour, unchanged)
    final favorites = _filtered.where((e) => e.isFavorite).toList();
    final websites = _filtered
        .where((e) => !e.isFavorite && e.category == 'website')
        .toList();
    final mobile = _filtered
        .where((e) => !e.isFavorite && e.category == 'mobile')
        .toList();
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

        // ── Favorites section ────────────────────────────────────────────
        if (favorites.isNotEmpty) ...[
          _sectionLabel('FAVORITES', Icons.star_rounded),
          const SizedBox(height: 10),
          ...favorites.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _VaultItem(
                entry: e,
                tagById: tagById,
                isOverdue: overdueIds.contains(e.id),
                onDelete: () => _delete(e),
                onToggleFavorite: () => _toggleFavorite(e),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        if (websites.isNotEmpty) ...[
          _sectionLabel('WEBSITES', Icons.language),
          const SizedBox(height: 10),
          ...websites.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _VaultItem(
                entry: e,
                tagById: tagById,
                isOverdue: overdueIds.contains(e.id),
                onDelete: () => _delete(e),
                onToggleFavorite: () => _toggleFavorite(e),
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
                tagById: tagById,
                isOverdue: overdueIds.contains(e.id),
                onDelete: () => _delete(e),
                onToggleFavorite: () => _toggleFavorite(e),
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

// ── Tag filter bar ────────────────────────────────────────────────────────────

class _TagFilterBar extends StatelessWidget {
  final List<Tag> tags;
  final int? activeTagId;
  final ValueChanged<int?> onSelect;

  const _TagFilterBar({
    required this.tags,
    required this.activeTagId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // "All" chip
          _FilterChip(
            label: 'All',
            color: AppColors.primary,
            isActive: activeTagId == null,
            onTap: () => onSelect(null),
          ),
          ...tags.map(
            (tag) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _FilterChip(
                label: tag.name,
                color: Color(tag.color),
                isActive: activeTagId == tag.id,
                onTap: () => onSelect(activeTagId == tag.id ? null : tag.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.color,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.18)
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color : AppColors.surface,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: isActive ? color : AppColors.textSecondary,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
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
  final Map<int, Tag> tagById;
  final bool isOverdue;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;

  const _VaultItem({
    required this.entry,
    required this.tagById,
    required this.isOverdue,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final isWebsite = entry.category == 'website';

    // Resolve tag objects for this entry (preserving insertion order).
    final entryTags = entry.tagIds
        .map((id) => tagById[id])
        .whereType<Tag>()
        .toList();

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false;
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
                if (saved == true) vaultState?._load();
              });
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // App / website icon
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
                        if (entry.username.isNotEmpty ||
                            entry.url.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            entry.username.isNotEmpty
                                ? entry.username
                                : entry.url,
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

                  // Favorite star
                  GestureDetector(
                    onTap: onToggleFavorite,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        entry.isFavorite
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: entry.isFavorite
                            ? const Color(0xFFFFB347)
                            : AppColors.textHint,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),

                  // Category badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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

              // ── Tag chips row ────────────────────────────────────────
              if (entryTags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: entryTags.map((tag) {
                    final color = Color(tag.color);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: color.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.label, color: color, size: 10),
                          const SizedBox(width: 4),
                          Text(
                            tag.name,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
