import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const String _themeKey = 'theme_mode';

  static Future<ThemeMode> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();

    final theme = prefs.getString(_themeKey);

    switch (theme) {
      case 'light':
        return ThemeMode.light;

      case 'dark':
        return ThemeMode.dark;

      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  static Future<void> saveTheme(
    ThemeMode mode,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    switch (mode) {
      case ThemeMode.light:
        await prefs.setString(
          _themeKey,
          'light',
        );
        break;

      case ThemeMode.dark:
        await prefs.setString(
          _themeKey,
          'dark',
        );
        break;

      case ThemeMode.system:
        await prefs.setString(
          _themeKey,
          'system',
        );
        break;
    }
  }
}