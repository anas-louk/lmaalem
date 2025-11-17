import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/firebase/firebase_init.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';
import 'controllers/auth_controller.dart';
import 'controllers/language_controller.dart';
import 'core/translations/app_translations.dart';
import 'core/services/local_notification_service.dart';

// Top-level function to handle background messages (must be top-level or static)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if not already initialized
  await Firebase.initializeApp();
  
  debugPrint('[Background] Handling background message: ${message.messageId}');
  debugPrint('[Background] Title: ${message.notification?.title}');
  debugPrint('[Background] Body: ${message.notification?.body}');
  debugPrint('[Background] Data: ${message.data}');
  
  // Show local notification for background messages
  final notificationService = LocalNotificationService();
  await notificationService.initialize();
  
  if (message.notification != null) {
    await notificationService.showNotification(
      id: message.hashCode,
      title: message.notification!.title ?? 'Notification',
      body: message.notification!.body ?? '',
      payload: message.data['requestId'] ?? message.data['type'],
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up background message handler BEFORE initializing Firebase
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

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
