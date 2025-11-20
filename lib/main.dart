import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'core/firebase/firebase_init.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';
import 'controllers/auth_controller.dart';
import 'controllers/language_controller.dart';
import 'core/translations/app_translations.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/background_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Notifications: Using Firestore streams + local notifications + background polling
  // - Foreground: Firestore streams detect changes and show local notifications
  // - Background (minimized): WorkManager + Timer polling checks Firestore periodically
  // - Terminated: WorkManager continues running (every 15 minutes minimum)

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

  // Initialize WorkManager for background tasks
  try {
    await BackgroundNotificationService().initializeWorkManager();
  } catch (e) {
    debugPrint('Erreur lors de l\'initialisation de WorkManager: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final BackgroundNotificationService _backgroundService = BackgroundNotificationService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backgroundService.dispose().catchError((e) {
      debugPrint('[MyApp] Error disposing background service: $e');
    });
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Handle app lifecycle changes for background notifications
    switch (state) {
      case AppLifecycleState.resumed:
        // App is in foreground - stop polling, streams will handle notifications
        _backgroundService.stopBackgroundPolling();
        debugPrint('[MyApp] App resumed - stopping background polling');
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App is going to background - start polling
        _backgroundService.startBackgroundPolling();
        debugPrint('[MyApp] App backgrounded - starting background polling');
        break;
      case AppLifecycleState.detached:
        // App is being terminated
        _backgroundService.stopBackgroundPolling();
        break;
      case AppLifecycleState.hidden:
        // App is hidden (Android 12+)
        _backgroundService.startBackgroundPolling();
        break;
    }
  }

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
