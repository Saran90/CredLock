/// Shared password strength evaluation utility.
/// Extracted from CreatePasswordScreen so it can be reused by the
/// health dashboard without pulling in UI dependencies.
library;

enum PasswordStrength { none, weak, fair, good, strong }

extension PasswordStrengthExt on PasswordStrength {
  String get label => const {
    'none': '',
    'weak': 'Weak',
    'fair': 'Fair',
    'good': 'Good',
    'strong': 'Strong',
  }[name]!;
}

/// Returns the [PasswordStrength] for [pwd].
PasswordStrength evaluatePasswordStrength(String pwd) {
  if (pwd.isEmpty) return PasswordStrength.none;
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
  if (score <= 2) return PasswordStrength.weak;
  if (score <= 4) return PasswordStrength.fair;
  if (score <= 6) return PasswordStrength.good;
  return PasswordStrength.strong;
}
