import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color primaryPurple = Color(0xFF7C3AED);

  static const Color background = Color(0xFFF8FAFC);
  static const Color white = Colors.white;

  static const Color textDark = Color(0xFF1F2937);
  static const Color textLight = Color(0xFF6B7280);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [
      primaryBlue,
      primaryPurple,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}