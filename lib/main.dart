import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/firebase/firebase_init.dart';
import 'routes/app_routes.dart';
import 'theme/dark_theme.dart';
import 'controllers/auth_controller.dart';
import 'controllers/call_controller.dart';
import 'controllers/language_controller.dart';
import 'controllers/theme_controller.dart';
import 'core/translations/app_translations.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/background_notification_service.dart';
import 'core/services/push_notifications.dart';
import 'core/services/chat_notification_service.dart';
import 'core/helpers/snackbar_helper.dart';
import 'utils/battery_optimization.dart';
import 'services/stripe_service.dart';
import 'config/stripe_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configurer le mode plein écran pour utiliser tout l'espace disponible
  // La barre de statut et les boutons de navigation seront transparents
  // et s'adapteront au thème via AnnotatedRegion dans le build
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

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

  // Enregistrer le handler FCM pour les messages de fond (background / terminated)
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialiser le service de notifications locales
  try {
    await LocalNotificationService().initialize();
  } catch (e) {
    debugPrint('Erreur lors de l\'initialisation des notifications: $e');
  }

  // Initialiser Stripe
  try {
    if (StripeConfig.isConfigured) {
      await StripeService().initialize();
      debugPrint('Stripe initialisé avec succès');
    } else {
      debugPrint('⚠️ Stripe non configuré. Veuillez configurer StripeConfig.');
    }
  } catch (e) {
    debugPrint('Erreur lors de l\'initialisation de Stripe: $e');
  }

  // Initialiser le service FCM (foreground + onMessageOpenedApp)
  try {
    await PushNotificationService().initialize();
  } catch (e) {
    debugPrint('Erreur lors de l\'initialisation de FCM: $e');
  }

  // Initialize WorkManager for background tasks
  try {
    await BackgroundNotificationService().initializeWorkManager();
  } catch (e) {
    debugPrint('Erreur lors de l\'initialisation de WorkManager: $e');
  }

  // Initialiser le service de notifications de chat (doit être après GetX)
  // On l'initialisera après que GetX soit prêt dans initialBinding

  runApp(const MyApp());
}

/// Fonction helper pour mettre à jour le style système (mode sombre uniquement)
void _updateSystemUIOverlayStyle(ThemeMode themeMode) {
  // L'application utilise uniquement le mode sombre
  final SystemUiOverlayStyle systemUiOverlayStyle;
  
  if (Platform.isAndroid) {
    // Mode sombre : icônes claires
    systemUiOverlayStyle = SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    );
  } else {
    // Pour iOS
    systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    );
  }
  
  SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
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
        // Check battery optimization status if user returned from settings
        BatteryOptimization.checkStatusOnResume();
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
    // Initialiser les contrôleurs
    final languageController = Get.put(LanguageController());
    Get.put(ThemeController()); // Initialiser le contrôleur de thème
    
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
          scaffoldMessengerKey: SnackbarHelper.scaffoldMessengerKey,
          theme: DarkTheme.theme, // Utiliser uniquement le thème sombre
          darkTheme: DarkTheme.theme,
          themeMode: ThemeMode.dark, // Forcer le mode sombre
          
          // Translations
          translations: AppTranslations(),
          locale: locale,
          fallbackLocale: const Locale('fr', 'FR'),
          
          // RTL Support for Arabic + System UI Overlay Style (mode sombre uniquement)
          builder: (context, child) {
            // L'application utilise uniquement le mode sombre
            final SystemUiOverlayStyle systemUiOverlayStyle;
            
            if (Platform.isAndroid) {
              // Mode sombre : icônes claires
              systemUiOverlayStyle = SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarDividerColor: Colors.transparent,
                systemNavigationBarContrastEnforced: false,
              );
            } else {
              // Pour iOS
              systemUiOverlayStyle = SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.light,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarIconBrightness: Brightness.light,
                systemNavigationBarDividerColor: Colors.transparent,
                systemNavigationBarContrastEnforced: false,
              );
            }
            
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: systemUiOverlayStyle,
              child: Directionality(
                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                child: child!,
              ),
            );
          },
          
          // Routes
          initialRoute: '/',
          getPages: AppRoutes.getRoutes(),
          
          // Initialiser les controllers globaux
          initialBinding: BindingsBuilder(() {
            Get.put(AuthController());
            final callController = Get.put(CallController());
            
            // Mettre à jour le style système (mode sombre uniquement)
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateSystemUIOverlayStyle(ThemeMode.dark);
            });
            
            // Start listening for incoming calls when user is authenticated
            final authController = Get.find<AuthController>();
            ever(authController.currentUser, (user) {
              if (user != null) {
                callController.listenForIncomingCalls();
                // Initialiser le service de notifications de chat
                ChatNotificationService().initialize();
              }
            });
            // Also check if user is already logged in
            if (authController.currentUser.value != null) {
              callController.listenForIncomingCalls();
              // Initialiser le service de notifications de chat
              ChatNotificationService().initialize();
            }
          }),
        );
      },
    );
  }
}
