import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/tag.dart';
import '../../data/repositories/tag_repository.dart';

/// Full-screen manager for user-defined tags.
/// Opened from the VaultScreen app-bar.  Returns [true] if the tag list was
/// mutated so the caller can reload.
class TagManagementScreen extends StatefulWidget {
  const TagManagementScreen({super.key});

  @override
  State<TagManagementScreen> createState() => _TagManagementScreenState();
}

class _TagManagementScreenState extends State<TagManagementScreen> {
  List<Tag> _tags = [];
  bool _loading = true;
  bool _mutated = false; // track whether caller needs to reload

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tags = await TagRepository.instance.getAll();
    if (!mounted) return;
    setState(() {
      _tags = tags;
      _loading = false;
    });
  }

  Future<void> _openCreateSheet() async {
    final created = await _showTagSheet(context, null);
    if (created != null) {
      await TagRepository.instance.insert(created);
      _mutated = true;
      await _load();
    }
  }

  Future<void> _openEditSheet(Tag tag) async {
    final updated = await _showTagSheet(context, tag);
    if (updated != null) {
      await TagRepository.instance.update(updated.copyWith(id: tag.id));
      _mutated = true;
      await _load();
    }
  }

  Future<void> _confirmDelete(Tag tag) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Delete tag?', style: AppTextStyles.titleLarge),
        content: Text(
          'Remove "${tag.name}" from all entries?',
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
    if (confirm == true && tag.id != null) {
      await TagRepository.instance.delete(tag.id!);
      _mutated = true;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage tags'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => Navigator.of(context).pop(_mutated),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add, color: AppColors.primary),
              tooltip: 'New tag',
              onPressed: _openCreateSheet,
            ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _tags.isEmpty
            ? _buildEmpty()
            : _buildList(),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.cardBackground,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.label_outline,
              color: AppColors.textHint,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          const Text('No tags yet', style: AppTextStyles.titleMedium),
          const SizedBox(height: 6),
          const Text(
            'Tap + to create your first tag',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      itemCount: _tags.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _TagTile(
        tag: _tags[i],
        onEdit: () => _openEditSheet(_tags[i]),
        onDelete: () => _confirmDelete(_tags[i]),
      ),
    );
  }
}

// ── Individual tag tile ───────────────────────────────────────────────────────

class _TagTile extends StatelessWidget {
  final Tag tag;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TagTile({
    required this.tag,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(tag.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Color swatch
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(Icons.label, color: color, size: 14),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(tag.name, style: AppTextStyles.titleMedium)),
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              color: AppColors.textSecondary,
              size: 18,
            ),
            onPressed: onEdit,
            tooltip: 'Rename',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: AppColors.error,
              size: 18,
            ),
            onPressed: onDelete,
            tooltip: 'Delete',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.only(left: 8),
          ),
        ],
      ),
    );
  }
}

// ── Create / edit bottom sheet ────────────────────────────────────────────────

/// Shows a modal sheet for creating or editing a tag.
/// Returns a [Tag] (without id) on confirm, or null on cancel.
Future<Tag?> _showTagSheet(BuildContext context, Tag? existing) {
  return showModalBottomSheet<Tag>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _TagSheet(existing: existing),
  );
}

class _TagSheet extends StatefulWidget {
  final Tag? existing;
  const _TagSheet({this.existing});

  @override
  State<_TagSheet> createState() => _TagSheetState();
}

class _TagSheetState extends State<_TagSheet> {
  late final TextEditingController _nameCtrl;
  late int _selectedColor;

  // Palette of pre-defined ARGB colors
  static const List<int> _palette = [
    0xFFE53935, // red
    0xFFFF8C00, // orange (brand)
    0xFFFFB347, // amber
    0xFF4CAF50, // green
    0xFF00BCD4, // cyan
    0xFF2196F3, // blue
    0xFF9C27B0, // purple
    0xFFE91E63, // pink
    0xFF607D8B, // blue-grey
    0xFF795548, // brown
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _selectedColor = widget.existing?.color ?? _palette[0];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(Tag(name: name, color: _selectedColor));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.existing != null ? 'Edit tag' : 'New tag',
            style: AppTextStyles.headlineMedium,
          ),
          const SizedBox(height: 20),

          // Name field
          Text('TAG NAME', style: AppTextStyles.labelSmall),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: _nameCtrl,
              autofocus: true,
              style: AppTextStyles.bodyMedium,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'e.g. Work, Banking, Family',
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textHint,
                ),
                prefixIcon: const Icon(
                  Icons.label_outline,
                  color: AppColors.textHint,
                  size: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onSubmitted: (_) => _confirm(),
            ),
          ),
          const SizedBox(height: 24),

          // Color picker
          Text('COLOR', style: AppTextStyles.labelSmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _palette.map((argb) {
              final isSelected = argb == _selectedColor;
              final color = Color(argb);
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = argb),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.textPrimary
                          : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirm,
              child: Text(
                widget.existing != null ? 'SAVE CHANGES' : 'CREATE TAG',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Public helper used by CreatePasswordScreen ────────────────────────────────

/// Shows a compact bottom sheet that lets the user create a brand-new tag
/// without navigating away.  Returns the saved [Tag] (with id) or null.
Future<Tag?> showQuickCreateTagSheet(BuildContext context) async {
  final draft = await _showTagSheet(context, null);
  if (draft == null) return null;
  return TagRepository.instance.insert(draft);
}
