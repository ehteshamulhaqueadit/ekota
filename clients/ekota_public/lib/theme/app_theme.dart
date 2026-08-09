import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF1E3A8A); // Deep Navy Blue
  static const Color primaryAccent = Color(0xFF2563EB); // Royal Blue
  static const Color background = Color(0xFF0F172A); // Midnight Dark Slate
  static const Color cardBackground = Color(0xFF1E293B); // Slate Surface Card
  static const Color cardBorder = Color(0xFF334155); // Muted Border

  static const Color textPrimary = Color(0xFFF8FAFC); // Crisp Light Text
  static const Color textSecondary = Color(0xFF94A3B8); // Muted Gray Text
  static const Color textMuted = Color(0xFF64748B); // Subdued Gray

  static const Color success = Color(0xFF10B981); // Emerald Green
  static const Color successBg = Color(0x1F10B981); // Emerald Tint
  static const Color warning = Color(0xFFF59E0B); // Amber Warning
  static const Color warningBg = Color(0x1FF59E0B); // Amber Tint
  static const Color error = Color(0xFFEF4444); // Crimson Error
  static const Color errorBg = Color(0x1FEF4444); // Crimson Tint
  static const Color neutralGray = Color(0xFF64748B);
  static const Color neutralBg = Color(0x1F64748B);
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
}

class AppTextStyles {
  static const TextStyle h1 = TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary);
  static const TextStyle h2 = TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary);
  static const TextStyle h3 = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static const TextStyle body = TextStyle(fontSize: 14, color: AppColors.textPrimary);
  static const TextStyle bodySecondary = TextStyle(fontSize: 12, color: AppColors.textSecondary);
  static const TextStyle amountLarge = TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary);
  static const TextStyle badgeText = TextStyle(fontSize: 11, fontWeight: FontWeight.bold);
}
