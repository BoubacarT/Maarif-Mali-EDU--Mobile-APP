import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contrôleur global clair/sombre, persisté localement.
class ThemeController {
  static const _key = 'maarif_theme_mode';
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      mode.value = (prefs.getString(_key) == 'dark') ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {}
  }

  static Future<void> setDark(bool dark) async {
    mode.value = dark ? ThemeMode.dark : ThemeMode.light;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, dark ? 'dark' : 'light');
    } catch (_) {}
  }

  static bool get isDark => mode.value == ThemeMode.dark;
}
