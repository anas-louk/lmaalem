import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contrôleur pour gérer le thème de l'application (Light/Dark/System)
class ThemeController extends GetxController {
  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;
  
  static const String _prefsThemeModeKey = 'theme_mode';
  
  @override
  void onInit() {
    super.onInit();
    _loadThemeMode();
  }
  
  /// Charger le mode de thème sauvegardé
  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedThemeMode = prefs.getString(_prefsThemeModeKey);
      
      if (savedThemeMode != null) {
        switch (savedThemeMode) {
          case 'light':
            themeMode.value = ThemeMode.light;
            break;
          case 'dark':
            themeMode.value = ThemeMode.dark;
            break;
          case 'system':
          default:
            themeMode.value = ThemeMode.system;
            break;
        }
      } else {
        // Par défaut, utiliser le mode système
        themeMode.value = ThemeMode.system;
      }
    } catch (e) {
      // En cas d'erreur, utiliser le mode système par défaut
      themeMode.value = ThemeMode.system;
    }
  }
  
  /// Changer le mode de thème
  Future<void> setThemeMode(ThemeMode mode) async {
    try {
      themeMode.value = mode;
      
      // Sauvegarder la préférence
      final prefs = await SharedPreferences.getInstance();
      String modeString;
      switch (mode) {
        case ThemeMode.light:
          modeString = 'light';
          break;
        case ThemeMode.dark:
          modeString = 'dark';
          break;
        case ThemeMode.system:
          modeString = 'system';
          break;
      }
      await prefs.setString(_prefsThemeModeKey, modeString);
    } catch (e) {
      debugPrint('Erreur lors de la sauvegarde du thème: $e');
    }
  }
  
  /// Basculer entre Light et Dark (ignore System)
  Future<void> toggleTheme() async {
    final currentMode = themeMode.value;
    if (currentMode == ThemeMode.light) {
      await setThemeMode(ThemeMode.dark);
    } else if (currentMode == ThemeMode.dark) {
      await setThemeMode(ThemeMode.light);
    } else {
      // Si System, basculer vers Light
      await setThemeMode(ThemeMode.light);
    }
  }
  
  /// Obtenir le nom du mode de thème
  String getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Clair';
      case ThemeMode.dark:
        return 'Sombre';
      case ThemeMode.system:
        return 'Système';
    }
  }
  
  /// Obtenir l'icône du mode de thème
  IconData getThemeModeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode_rounded;
      case ThemeMode.dark:
        return Icons.dark_mode_rounded;
      case ThemeMode.system:
        return Icons.brightness_auto_rounded;
    }
  }
}

