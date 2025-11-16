import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'core/firebase/firebase_init.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';
import 'controllers/auth_controller.dart';
import 'controllers/language_controller.dart';
import 'core/translations/app_translations.dart';
import 'core/services/local_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser Firebase
  try {
    await FirebaseInit.initialize();
  } catch (e) {
    debugPrint('Erreur lors de l\'initialisation de Firebase: $e');
  }

  // Initialiser le service de notifications locales
  try {
    await LocalNotificationService().initialize();
  } catch (e) {
    debugPrint('Erreur lors de l\'initialisation des notifications: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialiser le contrôleur de langue
    final languageController = Get.put(LanguageController());
    
    return Obx(
      () {
        // Déterminer la locale et la direction du texte
        final isRTL = languageController.currentLanguage.value == 'ar_SA';
        final locale = isRTL 
            ? const Locale('ar', 'SA') 
            : const Locale('fr', 'FR');
        
        return GetMaterialApp(
          title: 'Lmaalem',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          // darkTheme: AppTheme.darkTheme,
          // themeMode: ThemeMode.system,
          
          // Translations
          translations: AppTranslations(),
          locale: locale,
          fallbackLocale: const Locale('fr', 'FR'),
          
          // RTL Support for Arabic
          builder: (context, child) {
            return Directionality(
              textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
              child: child!,
            );
          },
          
          // Routes
          initialRoute: '/',
          getPages: AppRoutes.getRoutes(),
          
          // Initialiser les controllers globaux
          initialBinding: BindingsBuilder(() {
            Get.put(AuthController());
          }),
        );
      },
    );
  }
}
