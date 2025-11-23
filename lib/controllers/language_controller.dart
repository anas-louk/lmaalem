import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/helpers/snackbar_helper.dart';

class LanguageController extends GetxController {
  final RxString currentLanguage = 'fr_FR'.obs;
  
  @override
  void onInit() {
    super.onInit();
    _loadLanguage();
  }
  
  /// Charger la langue sauvegardée
  Future<void> _loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString('language') ?? 'fr_FR';
      currentLanguage.value = savedLanguage;
      _updateLocale(savedLanguage);
    } catch (e) {
      // Si erreur, utiliser le français par défaut
      currentLanguage.value = 'fr_FR';
      _updateLocale('fr_FR');
    }
  }
  
  /// Changer la langue
  Future<void> changeLanguage(String languageCode) async {
    try {
      currentLanguage.value = languageCode;
      _updateLocale(languageCode);
      
      // Sauvegarder la préférence
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', languageCode);
    } catch (e) {
      SnackbarHelper.showError('error_language_change'.tr);
    }
  }
  
  /// Mettre à jour la locale dans GetX
  void _updateLocale(String languageCode) {
    Locale locale;
    switch (languageCode) {
      case 'ar_SA':
        locale = const Locale('ar', 'SA');
        break;
      case 'fr_FR':
      default:
        locale = const Locale('fr', 'FR');
        break;
    }
    Get.updateLocale(locale);
  }
  
  /// Obtenir le nom de la langue
  String getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'ar_SA':
        return 'العربية';
      case 'fr_FR':
      default:
        return 'Français';
    }
  }
  
  /// Vérifier si la langue actuelle est l'arabe (pour RTL)
  bool get isRTL => currentLanguage.value == 'ar_SA';
}

