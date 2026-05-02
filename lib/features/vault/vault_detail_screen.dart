import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/password_entry.dart';
import '../create/create_password_screen.dart';

class VaultDetailScreen extends StatefulWidget {
  final PasswordEntry entry;

  const VaultDetailScreen({required this.entry, super.key});

  @override
  State<VaultDetailScreen> createState() => _VaultDetailScreenState();
}

class _VaultDetailScreenState extends State<VaultDetailScreen> {
  final Map<String, bool> _showPassword = {};
  final Map<String, bool> _copied = {};
  late PasswordEntry _entry;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _showPassword['password'] = false;
    _showPassword['pin'] = false;
  }

  Future<void> _openEdit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CreatePasswordScreen(entry: _entry)),
    );
    if (saved == true && mounted) {
      // Pop back to vault so it can reload — the vault will refresh the list
      Navigator.of(context).pop(true);
    }
  }

  void _copyToClipboard(String label, String value) async {
    if (value.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: value));

    if (!mounted) return;
    setState(() {
      _copied[label] = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primary.withValues(alpha: 0.9),
      ),
    );

    // Reset copied state after 2 seconds
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _copied[label] = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWebsite = _entry.category == 'website';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Password Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            tooltip: 'Edit',
            onPressed: _openEdit,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and name
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _entry.appIconBase64 != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            base64Decode(_entry.appIconBase64!),
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(
                          isWebsite ? Icons.language : Icons.smartphone,
                          color: AppColors.primary,
                          size: 24,
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_entry.name, style: AppTextStyles.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        isWebsite ? 'Website' : 'Mobile App',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Fields section
            if (_entry.url.isNotEmpty) ...[
              _buildField(
                label: 'URL',
                value: _entry.url,
                icon: Icons.link,
                copyable: true,
              ),
              const SizedBox(height: 16),
            ],
            if (_entry.username.isNotEmpty) ...[
              _buildField(
                label: 'Username/Email',
                value: _entry.username,
                icon: Icons.person,
                copyable: true,
              ),
              const SizedBox(height: 16),
            ],
            if (_entry.password.isNotEmpty) ...[
              _buildPasswordField(label: 'Password', value: _entry.password),
              const SizedBox(height: 16),
            ],
            if (_entry.pin != null && _entry.pin!.isNotEmpty) ...[
              _buildPasswordField(label: 'PIN', value: _entry.pin!),
              const SizedBox(height: 16),
            ],

            // Metadata
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Created', style: AppTextStyles.labelSmall),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(_entry.createdAt),
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Text('Last changed', style: AppTextStyles.labelSmall),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(_entry.lastUpdatedAt),
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String value,
    required IconData icon,
    required bool copyable,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textHint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.labelSmall),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTextStyles.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          if (copyable)
            IconButton(
              onPressed: () => _copyToClipboard(label, value),
              icon: Icon(
                _copied[label] == true
                    ? Icons.check_rounded
                    : Icons.copy_rounded,
                size: 20,
                color: _copied[label] == true
                    ? AppColors.primary
                    : AppColors.textHint,
              ),
              tooltip: 'Copy $label',
              splashRadius: 24,
            ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({required String label, required String value}) {
    final isShowing = _showPassword[label] ?? false;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            label == 'PIN' ? Icons.pin_outlined : Icons.lock_outline,
            size: 18,
            color: AppColors.textHint,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.labelSmall),
                const SizedBox(height: 4),
                Text(
                  isShowing ? value : '•' * value.length.clamp(0, 24),
                  style: AppTextStyles.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _showPassword[label] = !isShowing;
              });
            },
            icon: Icon(
              isShowing
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              size: 20,
              color: AppColors.textHint,
            ),
            tooltip: isShowing ? 'Hide' : 'Show',
            splashRadius: 24,
          ),
          IconButton(
            onPressed: () => _copyToClipboard(label, value),
            icon: Icon(
              _copied[label] == true ? Icons.check_rounded : Icons.copy_rounded,
              size: 20,
              color: _copied[label] == true
                  ? AppColors.primary
                  : AppColors.textHint,
            ),
            tooltip: 'Copy $label',
            splashRadius: 24,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
