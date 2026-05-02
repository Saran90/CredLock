import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Backgrounds
  static const Color background = Color(0xFF1A1A1A);
  static const Color surface = Color(0xFF252525);
  static const Color cardBackground = Color(0xFF2C2C2C);

  // Primary orange accent
  static const Color primary = Color(0xFFFF8C00);
  static const Color primaryLight = Color(0xFFFFB347);
  static const Color primaryDark = Color(0xFFE65C00);

  // Orange gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFFB347), Color(0xFFFF8C00), Color(0xFFE65C00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color textHint = Color(0xFF666666);

  // UI elements
  static const Color divider = Color(0xFF333333);
  static const Color inputUnderline = Color(0xFF444444);
  static const Color iconInactive = Color(0xFF666666);

  // Status
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
}
