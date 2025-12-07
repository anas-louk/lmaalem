import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Contrôleur pour gérer le thème de l'application (mode sombre uniquement)
class ThemeController extends GetxController {
  final Rx<ThemeMode> themeMode = ThemeMode.dark.obs;
  
  @override
  void onInit() {
    super.onInit();
    _loadThemeMode();
  }
  
  /// Charger le mode de thème sauvegardé (mode sombre uniquement)
  Future<void> _loadThemeMode() async {
    // L'application utilise uniquement le mode sombre
    themeMode.value = ThemeMode.dark;
  }
  
  /// Changer le mode de thème (mode sombre uniquement)
  Future<void> setThemeMode(ThemeMode mode) async {
    // L'application utilise uniquement le mode sombre
    // Ignorer toute tentative de changement vers light ou system
    themeMode.value = ThemeMode.dark;
  }
  
  /// Basculer le thème (désactivé - mode sombre uniquement)
  Future<void> toggleTheme() async {
    // L'application utilise uniquement le mode sombre
    // Cette fonction est désactivée
  }
  
  /// Obtenir le nom du mode de thème (mode sombre uniquement)
  String getThemeModeName(ThemeMode mode) {
    // L'application utilise uniquement le mode sombre
    return 'Sombre';
  }
  
  /// Obtenir l'icône du mode de thème (mode sombre uniquement)
  IconData getThemeModeIcon(ThemeMode mode) {
    // L'application utilise uniquement le mode sombre
    return Icons.dark_mode_rounded;
  }
}

