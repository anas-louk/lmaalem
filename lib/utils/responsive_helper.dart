import 'package:flutter/material.dart';

/// Helper pour gérer le responsive design
class ResponsiveHelper {
  ResponsiveHelper._(); // Private constructor

  /// Vérifier si c'est un mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  /// Vérifier si c'est une tablette
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 1024;
  }

  /// Vérifier si c'est un desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1024;
  }

  /// Obtenir la largeur de l'écran
  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Obtenir la hauteur de l'écran
  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// Obtenir le padding selon la taille de l'écran
  static EdgeInsets screenPadding(BuildContext context) {
    if (isDesktop(context)) {
      return const EdgeInsets.symmetric(horizontal: 48, vertical: 24);
    } else if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 20);
    } else {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 16);
    }
  }

  /// Obtenir le nombre de colonnes selon la taille de l'écran
  static int getColumnCount(BuildContext context) {
    if (isDesktop(context)) {
      return 4;
    } else if (isTablet(context)) {
      return 2;
    } else {
      return 1;
    }
  }
}

