import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/services/app_lookup_service.dart';
import '../../core/services/website_lookup_service.dart';
import '../../data/models/password_entry.dart';
import '../../data/repositories/password_repository.dart';

class CreatePasswordScreen extends StatefulWidget {
  /// Pass an existing entry to open in edit mode.
  final PasswordEntry? entry;

  const CreatePasswordScreen({super.key, this.entry});

  @override
  State<CreatePasswordScreen> createState() => _CreatePasswordScreenState();
}

class _CreatePasswordScreenState extends State<CreatePasswordScreen>
    with TickerProviderStateMixin {
  _Category _selectedCategory = _Category.website;

  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _showGenerator = false;

  // Date the password was last changed — user can override this
  late DateTime _lastChangedDate;

  int _genLength = 16;
  bool _genNumbers = true;
  bool _genLetters = true;
  bool _genSymbols = true;
  String _generatedPassword = '';

  _PasswordStrength _strength = _PasswordStrength.none;

  bool _hasPinEnabled = false;
  String _pin = '';
  String _confirmPin = '';
  bool _pinMismatch = false;

  // App lookup (mobile category only)
  List<AppMatch> _appSuggestions = [];
  String? _matchedPackage;
  String? _matchedIconBase64;
  bool _lookingUp = false;

  // Website lookup (website category only)
  String? _websiteFaviconBase64;
  bool _websiteLooking = false;
  Timer? _websiteDebounce;

  late final AnimationController _generatorAnim;
  late final Animation<double> _generatorHeight;
  late final AnimationController _pinAnim;
  late final Animation<double> _pinHeight;

  @override
  void initState() {
    super.initState();
    _generatorAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _generatorHeight = CurvedAnimation(
      parent: _generatorAnim,
      curve: Curves.easeOutCubic,
    );
    _pinAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _pinHeight = CurvedAnimation(parent: _pinAnim, curve: Curves.easeOutCubic);
    _passwordController.addListener(_onPasswordChanged);
    _nameController.addListener(_onNameChanged);

    // Pre-fill fields when editing an existing entry
    final existing = widget.entry;
    if (existing != null) {
      _selectedCategory = existing.category == 'mobile'
          ? _Category.mobile
          : _Category.website;
      _nameController.text = existing.name;
      _urlController.text = existing.url;
      _usernameController.text = existing.username;
      _passwordController.text = existing.password;
      _matchedPackage = existing.packageName;
      _matchedIconBase64 = existing.appIconBase64;
      _websiteFaviconBase64 = existing.category == 'website'
          ? existing.appIconBase64
          : null;
      if (existing.pin != null && existing.pin!.isNotEmpty) {
        _hasPinEnabled = true;
        _pin = existing.pin!;
        _confirmPin = existing.pin!;
        _pinAnim.value = 1.0;
      }
      _lastChangedDate = existing.lastUpdatedAt;
    } else {
      _lastChangedDate = DateTime.now();
    }

    _generatePassword();
    // App list is loaded lazily on first search — no preload here.
  }

  @override
  void dispose() {
    _websiteDebounce?.cancel();
    _generatorAnim.dispose();
    _pinAnim.dispose();
    _nameController.dispose();
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged() =>
      setState(() => _strength = _evaluateStrength(_passwordController.text));

  void _onNameChanged() {
    final query = _nameController.text;

    if (_selectedCategory == _Category.mobile) {
      // Mobile: app lookup
      if (query.isEmpty) {
        setState(() {
          _appSuggestions = [];
          _matchedPackage = null;
          _matchedIconBase64 = null;
        });
        return;
      }
      _doAppSearch(query);
    } else {
      // Website: favicon + URL lookup with debounce
      if (query.isEmpty) {
        _websiteDebounce?.cancel();
        setState(() {
          _websiteFaviconBase64 = null;
          _urlController.text = '';
        });
        return;
      }
      _websiteDebounce?.cancel();
      _websiteDebounce = Timer(const Duration(milliseconds: 700), () {
        _doWebsiteLookup(query);
      });
    }
  }

  Future<void> _doWebsiteLookup(String query) async {
    setState(() => _websiteLooking = true);
    final info = await WebsiteLookupService.instance.lookup(query);
    if (!mounted) return;
    setState(() {
      _websiteLooking = false;
      if (info != null) {
        _websiteFaviconBase64 = info.faviconBase64;
        // Auto-fill URL only if user hasn't typed one yet
        if (_urlController.text.isEmpty) {
          _urlController.text = info.url;
        }
      }
    });
  }

  void _clearWebsiteMatch() {
    setState(() {
      _websiteFaviconBase64 = null;
    });
  }

  Future<void> _doAppSearch(String query) async {
    setState(() => _lookingUp = true);
    final results = await AppLookupService.instance.search(query);
    if (!mounted) return;
    setState(() {
      _appSuggestions = results;
      _lookingUp = false;
    });
  }

  void _selectApp(AppMatch match) {
    _nameController.text = match.appName;
    _nameController.selection = TextSelection.fromPosition(
      TextPosition(offset: match.appName.length),
    );
    setState(() {
      _matchedPackage = match.packageName;
      _matchedIconBase64 = match.iconBase64;
      _appSuggestions = [];
    });
  }

  void _clearAppMatch() {
    setState(() {
      _matchedPackage = null;
      _matchedIconBase64 = null;
      _appSuggestions = [];
    });
  }

  void _toggleGenerator() {
    setState(() => _showGenerator = !_showGenerator);
    _showGenerator ? _generatorAnim.forward() : _generatorAnim.reverse();
  }

  void _generatePassword() {
    const letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';
    const symbols = r'!@#$%^&*()_+-=[]{}|;:,.<>?';
    String pool = '';
    if (_genLetters) pool += letters;
    if (_genNumbers) pool += numbers;
    if (_genSymbols) pool += symbols;
    if (pool.isEmpty) pool = letters;
    final rng = Random.secure();
    setState(
      () => _generatedPassword = List.generate(
        _genLength,
        (_) => pool[rng.nextInt(pool.length)],
      ).join(),
    );
  }

  void _useGeneratedPassword() {
    _passwordController.text = _generatedPassword;
    _passwordController.selection = TextSelection.fromPosition(
      TextPosition(offset: _generatedPassword.length),
    );
    _toggleGenerator();
  }

  void _togglePin(bool value) {
    setState(() {
      _hasPinEnabled = value;
      _pin = '';
      _confirmPin = '';
      _pinMismatch = false;
    });
    value ? _pinAnim.forward() : _pinAnim.reverse();
  }

  void _onPinDigit(String digit, bool isConfirm) {
    setState(() {
      _pinMismatch = false;
      if (isConfirm) {
        if (_confirmPin.length < 6) _confirmPin += digit;
      } else {
        if (_pin.length < 6) _pin += digit;
      }
    });
  }

  void _onPinDelete(bool isConfirm) {
    setState(() {
      _pinMismatch = false;
      if (isConfirm) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        }
      } else {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  _PasswordStrength _evaluateStrength(String pwd) {
    if (pwd.isEmpty) return _PasswordStrength.none;
    int score = 0;
    if (pwd.length >= 8) score++;
    if (pwd.length >= 12) score++;
    if (pwd.length >= 16) score++;
    if (pwd.contains(RegExp(r'[a-z]'))) score++;
    if (pwd.contains(RegExp(r'[A-Z]'))) score++;
    if (pwd.contains(RegExp(r'[0-9]'))) score++;
    if (pwd.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]'))) score++;
    if (RegExp(r'(.)\1{2,}').hasMatch(pwd)) score--;
    if (RegExp(
      r'(012|123|234|345|456|567|678|789|abc|bcd|cde)',
    ).hasMatch(pwd.toLowerCase())) {
      score--;
    }
    if (pwd.length >= 20) score++;
    if (score <= 2) return _PasswordStrength.weak;
    if (score <= 4) return _PasswordStrength.fair;
    if (score <= 6) return _PasswordStrength.good;
    return _PasswordStrength.strong;
  }

  Future<void> _onSave() async {
    if (_nameController.text.isEmpty) {
      _showSnack('Name is required.', AppColors.error);
      return;
    }
    if (_hasPinEnabled) {
      if (_pin.length < 4) {
        _showSnack('PIN must be at least 4 digits.', AppColors.error);
        return;
      }
      if (_pin != _confirmPin) {
        setState(() => _pinMismatch = true);
        _showSnack('PINs do not match.', AppColors.error);
        return;
      }
    }

    final existing = widget.entry;
    final now = DateTime.now();
    // Normalise the user-selected date to midnight, keep time as-is for today
    final isToday =
        _lastChangedDate.year == now.year &&
        _lastChangedDate.month == now.month &&
        _lastChangedDate.day == now.day;
    final lastUpdated = isToday
        ? now
        : DateTime(
            _lastChangedDate.year,
            _lastChangedDate.month,
            _lastChangedDate.day,
          );

    final entry = PasswordEntry(
      id: existing?.id,
      category: _selectedCategory == _Category.website ? 'website' : 'mobile',
      name: _nameController.text.trim(),
      url: _urlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      pin: _hasPinEnabled ? _pin : null,
      packageName: _matchedPackage,
      appIconBase64: _selectedCategory == _Category.mobile
          ? _matchedIconBase64
          : _websiteFaviconBase64,
      createdAt: existing?.createdAt ?? now,
      lastUpdatedAt: lastUpdated,
    );

    if (existing != null) {
      await PasswordRepository.instance.update(entry);
      if (!mounted) return;
      _showSnack('Password updated!', AppColors.success);
    } else {
      await PasswordRepository.instance.insert(entry);
      if (!mounted) return;
      _showSnack('Password saved!', AppColors.success);
    }
    Navigator.of(context).pop(true);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _pickLastChangedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastChangedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: Colors.black,
            surface: AppColors.cardBackground,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _lastChangedDate = picked);
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    if (isToday) return 'Today';
    return '${date.day} ${_monthName(date.month)} ${date.year}';
  }

  String _monthName(int month) => const [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('credlock'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined, color: AppColors.primary),
            onPressed: _onSave,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.entry != null ? 'Edit password' : 'Add new password',
                style: AppTextStyles.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text('Fill in the details below', style: AppTextStyles.bodySmall),
              const SizedBox(height: 28),

              Text('CATEGORY', style: AppTextStyles.labelSmall),
              const SizedBox(height: 12),
              _CategorySelector(
                selected: _selectedCategory,
                onChanged: (c) {
                  setState(() {
                    _selectedCategory = c;
                    // Clear both lookup states on category switch
                    _websiteFaviconBase64 = null;
                    _websiteDebounce?.cancel();
                    // Reset PIN when switching to website
                    if (c == _Category.website && _hasPinEnabled) {
                      _hasPinEnabled = false;
                      _pin = '';
                      _confirmPin = '';
                      _pinMismatch = false;
                      _pinAnim.reverse();
                    }
                  });
                  if (c != _Category.mobile) {
                    _clearAppMatch();
                  } else if (_nameController.text.isNotEmpty) {
                    _doAppSearch(_nameController.text);
                  }
                },
              ),
              const SizedBox(height: 28),

              _buildLabel(
                _selectedCategory == _Category.website
                    ? 'WEBSITE NAME'
                    : 'APP NAME',
              ),
              const SizedBox(height: 8),
              // App icon preview + name field + suggestions
              _AppNameField(
                controller: _nameController,
                category: _selectedCategory,
                iconBase64: _selectedCategory == _Category.mobile
                    ? _matchedIconBase64
                    : _websiteFaviconBase64,
                suggestions: _appSuggestions,
                isLooking: _selectedCategory == _Category.mobile
                    ? _lookingUp
                    : _websiteLooking,
                onSelectApp: _selectApp,
                onClearMatch: _selectedCategory == _Category.mobile
                    ? _clearAppMatch
                    : _clearWebsiteMatch,
              ),
              const SizedBox(height: 20),

              _buildLabel(
                _selectedCategory == _Category.website
                    ? 'WEBSITE URL'
                    : 'BUNDLE ID / STORE URL',
              ),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _urlController,
                hint: _selectedCategory == _Category.website
                    ? 'https://example.com'
                    : 'com.example.app',
                icon: Icons.link,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 20),

              _buildLabel('USERNAME / EMAIL'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _usernameController,
                hint: 'user@example.com',
                icon: Icons.person_outline,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  _buildLabel('PASSWORD'),
                  const Spacer(),
                  GestureDetector(
                    onTap: _toggleGenerator,
                    child: Row(
                      children: [
                        Icon(
                          _showGenerator ? Icons.close : Icons.auto_awesome,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _showGenerator ? 'Close' : 'Generate',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildPasswordField(),
              const SizedBox(height: 12),
              _StrengthMeter(strength: _strength),
              const SizedBox(height: 16),
              SizeTransition(
                sizeFactor: _generatorHeight,
                axisAlignment: -1,
                child: _GeneratorPanel(
                  length: _genLength,
                  useNumbers: _genNumbers,
                  useLetters: _genLetters,
                  useSymbols: _genSymbols,
                  generatedPassword: _generatedPassword,
                  onLengthChanged: (v) {
                    setState(() => _genLength = v.round());
                    _generatePassword();
                  },
                  onNumbersChanged: (v) {
                    setState(() => _genNumbers = v);
                    _generatePassword();
                  },
                  onLettersChanged: (v) {
                    setState(() => _genLetters = v);
                    _generatePassword();
                  },
                  onSymbolsChanged: (v) {
                    setState(() => _genSymbols = v);
                    _generatePassword();
                  },
                  onRefresh: _generatePassword,
                  onUse: _useGeneratedPassword,
                ),
              ),
              const SizedBox(height: 32),

              if (_selectedCategory == _Category.mobile) ...[
                _PinToggleHeader(enabled: _hasPinEnabled, onToggle: _togglePin),
                SizeTransition(
                  sizeFactor: _pinHeight,
                  axisAlignment: -1,
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _PinInputSection(
                        label: 'SET PIN',
                        sublabel: '4–6 digit PIN for this entry',
                        pin: _pin,
                        maxLength: 6,
                        onDigit: (d) => _onPinDigit(d, false),
                        onDelete: () => _onPinDelete(false),
                      ),
                      const SizedBox(height: 20),
                      _PinInputSection(
                        label: 'CONFIRM PIN',
                        sublabel: 'Re-enter to confirm',
                        pin: _confirmPin,
                        maxLength: 6,
                        onDigit: (d) => _onPinDigit(d, true),
                        onDelete: () => _onPinDelete(true),
                        showMismatch: _pinMismatch,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],

              // ── Last changed date picker ──────────────────────────────
              _buildLabel('PASSWORD LAST CHANGED'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickLastChangedDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: AppColors.textHint,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _formatDate(_lastChangedDate),
                          style: AppTextStyles.bodyMedium,
                        ),
                      ),
                      const Icon(
                        Icons.edit_outlined,
                        color: AppColors.primary,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Set this to when you last changed this password. '
                'Reminders are calculated from this date.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _onSave,
                child: Text(
                  widget.entry != null ? 'UPDATE PASSWORD' : 'SAVE PASSWORD',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) =>
      Text(text, style: AppTextStyles.labelSmall);

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.textHint, size: 18),
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
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          filled: true,
          fillColor: AppColors.cardBackground,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        style: AppTextStyles.bodyMedium.copyWith(letterSpacing: 1.2),
        decoration: InputDecoration(
          hintText: 'Enter or generate a password',
          prefixIcon: const Icon(
            Icons.lock_outline,
            color: AppColors.textHint,
            size: 18,
          ),
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            child: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: AppColors.textSecondary,
              size: 18,
            ),
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
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          filled: true,
          fillColor: AppColors.cardBackground,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

// ── Category ──────────────────────────────────────────────────────────────────

enum _Category { website, mobile }

class _CategorySelector extends StatelessWidget {
  final _Category selected;
  final ValueChanged<_Category> onChanged;
  const _CategorySelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CategoryTile(
            icon: Icons.language,
            label: 'Website',
            sublabel: 'Browser login',
            isSelected: selected == _Category.website,
            onTap: () => onChanged(_Category.website),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _CategoryTile(
            icon: Icons.smartphone,
            label: 'Mobile App',
            sublabel: 'App login',
            isSelected: selected == _Category.mobile,
            onTap: () => onChanged(_Category.mobile),
          ),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final bool isSelected;
  final VoidCallback onTap;
  const _CategoryTile({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textHint,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
                Text(
                  sublabel,
                  style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Password strength ─────────────────────────────────────────────────────────

enum _PasswordStrength { none, weak, fair, good, strong }

extension _StrengthExt on _PasswordStrength {
  String get label => const {
    'none': '',
    'weak': 'Weak',
    'fair': 'Fair',
    'good': 'Good',
    'strong': 'Strong',
  }[name]!;

  Color get color {
    switch (this) {
      case _PasswordStrength.none:
        return Colors.transparent;
      case _PasswordStrength.weak:
        return const Color(0xFFE53935);
      case _PasswordStrength.fair:
        return const Color(0xFFFF8C00);
      case _PasswordStrength.good:
        return const Color(0xFFFFB347);
      case _PasswordStrength.strong:
        return const Color(0xFF4CAF50);
    }
  }

  int get filledBars {
    switch (this) {
      case _PasswordStrength.none:
        return 0;
      case _PasswordStrength.weak:
        return 1;
      case _PasswordStrength.fair:
        return 2;
      case _PasswordStrength.good:
        return 3;
      case _PasswordStrength.strong:
        return 4;
    }
  }
}

class _StrengthMeter extends StatelessWidget {
  final _PasswordStrength strength;
  const _StrengthMeter({required this.strength});

  @override
  Widget build(BuildContext context) {
    if (strength == _PasswordStrength.none) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) {
            final filled = i < strength.filledBars;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: filled ? strength.color : AppColors.surface,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                strength.label,
                key: ValueKey(strength),
                style: AppTextStyles.bodySmall.copyWith(
                  color: strength.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _hint(strength),
              style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  String _hint(_PasswordStrength s) {
    switch (s) {
      case _PasswordStrength.weak:
        return '— Too short or too simple';
      case _PasswordStrength.fair:
        return '— Add symbols or uppercase';
      case _PasswordStrength.good:
        return '— Almost there, increase length';
      case _PasswordStrength.strong:
        return '— Great! Hard to crack';
      default:
        return '';
    }
  }
}

// ── Generator panel ───────────────────────────────────────────────────────────

class _GeneratorPanel extends StatelessWidget {
  final int length;
  final bool useNumbers, useLetters, useSymbols;
  final String generatedPassword;
  final ValueChanged<double> onLengthChanged;
  final ValueChanged<bool> onNumbersChanged, onLettersChanged, onSymbolsChanged;
  final VoidCallback onRefresh, onUse;

  const _GeneratorPanel({
    required this.length,
    required this.useNumbers,
    required this.useLetters,
    required this.useSymbols,
    required this.generatedPassword,
    required this.onLengthChanged,
    required this.onNumbersChanged,
    required this.onLettersChanged,
    required this.onSymbolsChanged,
    required this.onRefresh,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: AppColors.primary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Password Generator',
                style: AppTextStyles.titleMedium.copyWith(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    generatedPassword,
                    style: AppTextStyles.generatedPassword.copyWith(
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: generatedPassword));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Copied'),
                        backgroundColor: AppColors.surface,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.copy,
                      color: AppColors.textSecondary,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onRefresh,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.refresh,
                      color: AppColors.primary,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('LENGTH', style: AppTextStyles.labelSmall),
              const SizedBox(width: 8),
              Text(
                '$length',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: length.toDouble(),
              min: 6,
              max: 32,
              divisions: 26,
              onChanged: onLengthChanged,
            ),
          ),
          const SizedBox(height: 8),
          Text('INCLUDE', style: AppTextStyles.labelSmall),
          const SizedBox(height: 8),
          _ToggleRow(
            label: 'Numbers  (0–9)',
            value: useNumbers,
            onChanged: onNumbersChanged,
          ),
          _ToggleRow(
            label: 'Letters  (A–z)',
            value: useLetters,
            onChanged: onLettersChanged,
          ),
          _ToggleRow(
            label: r'Symbols  (!@#$)',
            value: useSymbols,
            onChanged: onSymbolsChanged,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onUse,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
              child: const Text('USE THIS PASSWORD'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ── PIN section ───────────────────────────────────────────────────────────────

class _PinToggleHeader extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onToggle;
  const _PinToggleHeader({required this.enabled, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: enabled
            ? AppColors.primary.withValues(alpha: 0.10)
            : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.4)
              : Colors.transparent,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: enabled
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.pin_outlined,
              color: enabled ? AppColors.primary : AppColors.textHint,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'App PIN',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: enabled ? AppColors.primary : AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Some apps have a separate PIN lock',
                  style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(value: enabled, onChanged: onToggle),
        ],
      ),
    );
  }
}

class _PinInputSection extends StatelessWidget {
  final String label, sublabel, pin;
  final int maxLength;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final bool showMismatch;

  const _PinInputSection({
    required this.label,
    required this.sublabel,
    required this.pin,
    required this.maxLength,
    required this.onDigit,
    required this.onDelete,
    this.showMismatch = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: showMismatch
              ? AppColors.error.withValues(alpha: 0.6)
              : AppColors.primary.withValues(alpha: 0.15),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: AppTextStyles.labelSmall),
              const SizedBox(width: 6),
              Text(
                sublabel,
                style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
              ),
              const Spacer(),
              if (showMismatch)
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Mismatch',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.error,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(maxLength, (i) {
              final filled = i < pin.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: filled ? 14 : 12,
                height: filled ? 14 : 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled
                      ? (showMismatch ? AppColors.error : AppColors.primary)
                      : AppColors.surface,
                  border: Border.all(
                    color: filled
                        ? (showMismatch ? AppColors.error : AppColors.primary)
                        : AppColors.textHint.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          _Numpad(
            onDigit: pin.length < maxLength ? onDigit : (_) {},
            onDelete: onDelete,
          ),
        ],
      ),
    );
  }
}

class _Numpad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  const _Numpad({required this.onDigit, required this.onDelete});

  static const _keys = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', '<'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _keys
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: row.map((key) {
                  if (key.isEmpty) return const SizedBox(width: 72, height: 44);
                  final isDel = key == '<';
                  return GestureDetector(
                    onTap: () => isDel ? onDelete() : onDigit(key),
                    child: Container(
                      width: 72,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDel
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: isDel
                            ? const Icon(
                                Icons.backspace_outlined,
                                color: AppColors.primary,
                                size: 18,
                              )
                            : Text(
                                key,
                                style: AppTextStyles.titleMedium.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ── App name field with icon preview + suggestions ────────────────────────────

class _AppNameField extends StatefulWidget {
  final TextEditingController controller;
  final _Category category;
  final String? iconBase64;
  final List<AppMatch> suggestions;
  final bool isLooking;
  final ValueChanged<AppMatch> onSelectApp;
  final VoidCallback onClearMatch;

  const _AppNameField({
    required this.controller,
    required this.category,
    required this.iconBase64,
    required this.suggestions,
    required this.isLooking,
    required this.onSelectApp,
    required this.onClearMatch,
  });

  @override
  State<_AppNameField> createState() => _AppNameFieldState();
}

class _AppNameFieldState extends State<_AppNameField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = widget.category == _Category.mobile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name input row with icon preview
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isFocused ? AppColors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // App icon or default icon
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: widget.iconBase64 != null
                      ? GestureDetector(
                          key: const ValueKey('icon'),
                          onTap: widget.onClearMatch,
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  base64Decode(widget.iconBase64!),
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: const BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 9,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Icon(
                          key: const ValueKey('placeholder'),
                          isMobile ? Icons.smartphone : Icons.language,
                          color: _isFocused
                              ? AppColors.primary
                              : AppColors.textHint,
                          size: 20,
                        ),
                ),
              ),
              // Text field — borders removed, outer container handles styling
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  style: AppTextStyles.bodyMedium,
                  decoration: InputDecoration(
                    hintText: isMobile
                        ? 'e.g. Instagram, Spotify'
                        : 'e.g. Google, GitHub',
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
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.cardBackground,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 12,
                    ),
                    suffixIcon: widget.isLooking
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Suggestions dropdown (mobile only)
        if (isMobile && widget.suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: widget.suggestions.asMap().entries.map((e) {
                final i = e.key;
                final match = e.value;
                return InkWell(
                  onTap: () => widget.onSelectApp(match),
                  borderRadius: BorderRadius.vertical(
                    top: i == 0 ? const Radius.circular(10) : Radius.zero,
                    bottom: i == widget.suggestions.length - 1
                        ? const Radius.circular(10)
                        : Radius.zero,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: i < widget.suggestions.length - 1
                          ? const Border(
                              bottom: BorderSide(
                                color: AppColors.divider,
                                width: 0.5,
                              ),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        if (match.iconBase64 != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Image.memory(
                              base64Decode(match.iconBase64!),
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Icon(
                              Icons.android,
                              color: AppColors.textHint,
                              size: 20,
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                match.appName,
                                style: AppTextStyles.titleMedium.copyWith(
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                match.packageName,
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontSize: 10,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: AppColors.textHint,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
