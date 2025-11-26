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

  /// Obtenir les insets de safe area (pour gérer les barres de navigation système)
  static EdgeInsets getSafeAreaInsets(BuildContext context) {
    return MediaQuery.of(context).padding;
  }

  /// Obtenir le padding bottom pour les barres de navigation système
  static double getBottomPadding(BuildContext context) {
    return MediaQuery.of(context).padding.bottom;
  }

  /// Obtenir le padding top pour la barre de statut
  static double getTopPadding(BuildContext context) {
    return MediaQuery.of(context).padding.top;
  }

  /// Vérifier si l'appareil a des boutons de navigation système
  static bool hasSystemNavigationButtons(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    // Si le padding bottom est significatif (> 0), il y a probablement des boutons système
    return bottomPadding > 0;
  }

  /// Obtenir le padding adaptatif pour le contenu (inclut les safe areas)
  static EdgeInsets getAdaptivePadding(BuildContext context, {
    EdgeInsets? additionalPadding,
  }) {
    final safeAreaInsets = getSafeAreaInsets(context);
    final contentPadding = screenPadding(context);
    
    return EdgeInsets.only(
      top: safeAreaInsets.top + contentPadding.top,
      bottom: safeAreaInsets.bottom + contentPadding.bottom,
      left: contentPadding.left,
      right: contentPadding.right,
    ) + (additionalPadding ?? EdgeInsets.zero);
  }
}

