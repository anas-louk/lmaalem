import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';

/// Initialise Firebase dans l'application
class FirebaseInit {
  static bool _initialized = false;

  /// Initialiser Firebase
  static Future<void> initialize() async {
    // Vérifier d'abord avec le flag
    if (_initialized) {
      debugPrint('[FirebaseInit] Déjà initialisé (flag)');
      return;
    }

    try {
      // Vérifier si Firebase est déjà initialisé en vérifiant la liste des apps
      if (Firebase.apps.isNotEmpty) {
        debugPrint('[FirebaseInit] Firebase déjà initialisé - ${Firebase.apps.length} app(s) trouvée(s)');
        _initialized = true;
        return;
      }

      // Firebase n'est pas encore initialisé, on l'initialise
      debugPrint('[FirebaseInit] Initialisation de Firebase...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('[FirebaseInit] Firebase initialisé avec succès');

      _initialized = true;
    } catch (e) {
      // Si l'erreur est "duplicate-app" ou "already exists", Firebase est déjà initialisé
      final errorString = e.toString();
      if (errorString.contains('duplicate-app') ||
          errorString.contains('already exists') ||
          errorString.contains('[DEFAULT]')) {
        _initialized = true;
        debugPrint('[FirebaseInit] Firebase déjà initialisé (erreur détectée et ignorée)');
        return;
      }
      debugPrint('[FirebaseInit] Erreur lors de l\'initialisation de Firebase: $e');
      // Ne pas rethrow pour éviter de bloquer l'app
    }
  }
}

