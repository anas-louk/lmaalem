import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'dart:io' show Platform;
import '../constants/app_routes.dart';
import '../../controllers/auth_controller.dart';

/// Service pour gérer les notifications locales dans la barre de statut
class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialiser le service de notifications
  /// Cette méthode est idempotente et peut être appelée plusieurs fois en toute sécurité
  Future<void> initialize() async {
    // Note: Dans un isolate séparé (comme le handler FCM en arrière-plan),
    // chaque appel crée une nouvelle instance, donc on ne peut pas compter sur _initialized.
    // On doit toujours vérifier si le plugin est déjà initialisé en appelant initialize().
    
    try {
      // Create notification channels for Android (required for Android 8.0+)
      // Cette opération est idempotente - créer un canal existant ne fait rien
      if (Platform.isAndroid) {
        await _createNotificationChannels();
      }

      // Configuration Android
      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // Configuration iOS
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // Configuration initiale
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // Initialiser le plugin (idempotent - peut être appelé plusieurs fois)
      final bool? initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      if (initialized == true) {
        _initialized = true;
        
        // Demander les permissions pour Android 13+
        // Cette opération est idempotente - demander une permission déjà accordée ne fait rien
        if (Platform.isAndroid) {
          await _requestAndroidPermissions();
        }
      } else {
        debugPrint('[LocalNotification] ⚠️ Échec de l\'initialisation des notifications locales');
      }
    } catch (e, stackTrace) {
      debugPrint('[LocalNotification] ❌ Erreur lors de l\'initialisation: $e');
      debugPrint('[LocalNotification] Stack trace: $stackTrace');
      // Ne pas lever l'exception - permettre à l'application de continuer
      // L'initialisation peut être réessayée plus tard
    }
  }

  /// Créer les canaux de notification pour Android
  Future<void> _createNotificationChannels() async {
    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation == null) return;

    // High importance channel for new requests and employee acceptances
    const AndroidNotificationChannel highImportanceChannel = AndroidNotificationChannel(
      'high_importance_channel',
      'Notifications importantes',
      description: 'Notifications pour les nouvelles demandes et acceptations',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // General channel
    const AndroidNotificationChannel generalChannel = AndroidNotificationChannel(
      'general_channel',
      'Notifications générales',
      description: 'Notifications générales de l\'application',
      importance: Importance.defaultImportance,
      playSound: true,
    );

    // Employee accepted channel
    const AndroidNotificationChannel employeeAcceptedChannel = AndroidNotificationChannel(
      'employee_accepted_channel',
      'Acceptations d\'employés',
      description: 'Notifications lorsqu\'un employé accepte votre demande',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // New requests channel
    const AndroidNotificationChannel newRequestsChannel = AndroidNotificationChannel(
      'new_requests_channel',
      'Nouvelles demandes',
      description: 'Notifications pour les nouvelles demandes de service',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // Incoming calls channel (for FCM audio call notifications)
    const AndroidNotificationChannel incomingCallsChannel = AndroidNotificationChannel(
      'incoming_calls',
      'Appels entrants',
      description: 'Notifications pour les appels audio entrants',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await androidImplementation.createNotificationChannel(highImportanceChannel);
    await androidImplementation.createNotificationChannel(generalChannel);
    await androidImplementation.createNotificationChannel(employeeAcceptedChannel);
    await androidImplementation.createNotificationChannel(newRequestsChannel);
    await androidImplementation.createNotificationChannel(incomingCallsChannel);
  }

  /// Demander les permissions Android
  Future<void> _requestAndroidPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final bool? granted = await androidImplementation.requestNotificationsPermission();
      if (granted == true) {
        print('Notifications permission granted');
      }
    }
  }

  /// Gérer le clic sur une notification
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[LocalNotification] Notification tapped: payload=${response.payload}');
    
    try {
      // Get current user to determine type
      final authController = Get.find<AuthController>();
      final user = authController.currentUser.value;
      
      if (user == null) {
        // User not logged in, go to login
        Get.offAllNamed(AppRoutes.login);
        return;
      }
      
      final payload = response.payload;
      final isEmployee = user.type.toLowerCase() == 'employee';
      
      // Determine notification type from payload
      // Payload is typically: requestId (for new requests or employee accepted)
      // Or notification type like "new_request", "employee_accepted", or callId
      if (payload != null) {
        // Check if it's a call notification (payload is callId)
        if (payload.startsWith('call_') || payload.contains('call')) {
          // Handle call notification - this should be handled by FCM handler
          // But if we get here, navigate to dashboard
          Get.offAllNamed(isEmployee ? AppRoutes.employeeDashboard : AppRoutes.clientDashboard);
          return;
        }
        
        // Check if payload is a notification type string
        if (payload == 'new_request') {
          // New request notification - redirect employee to notification screen
          if (isEmployee) {
            Get.offAllNamed(AppRoutes.employeeDashboard);
            // Navigate to notification screen after a short delay to ensure dashboard is loaded
            Future.delayed(const Duration(milliseconds: 300), () {
              Get.toNamed(AppRoutes.notifications);
            });
          } else {
            Get.offAllNamed(AppRoutes.clientDashboard);
          }
          return;
        }
        
        if (payload == 'employee_accepted') {
          // Employee accepted notification - redirect client to dashboard
          // (requestId should be in the notification data, but we'll go to dashboard)
          Get.offAllNamed(isEmployee ? AppRoutes.employeeDashboard : AppRoutes.clientDashboard);
          return;
        }
        
        // Payload is likely a requestId - determine navigation based on user type
        // For employees: 
        //   - new request notifications -> go to notification screen
        //   - client accepted employee notifications -> go to request detail to see accepted request
        // For clients: employee accepted notifications -> go to request detail
        if (isEmployee) {
          // Employee clicked on notification
          // Could be a new request or client accepted them
          // Navigate to request detail to see the request (if accepted, they'll see it's accepted)
          Get.offAllNamed(AppRoutes.employeeDashboard);
          Future.delayed(const Duration(milliseconds: 300), () {
            Get.toNamed(AppRoutes.requestDetail, arguments: payload);
          });
        } else {
          // Client clicked on notification - likely employee accepted their request
          // Navigate to request detail to see the accepted request
          Get.offAllNamed(AppRoutes.clientDashboard);
          Future.delayed(const Duration(milliseconds: 300), () {
            Get.toNamed(AppRoutes.requestDetail, arguments: payload);
          });
        }
      } else {
        // No payload - go to appropriate dashboard
        Get.offAllNamed(isEmployee ? AppRoutes.employeeDashboard : AppRoutes.clientDashboard);
      }
    } catch (e) {
      debugPrint('[LocalNotification] Error handling notification tap: $e');
      // Fallback: go to login or home
      try {
        Get.offAllNamed(AppRoutes.login);
      } catch (_) {
        // If routes not available, do nothing
      }
    }
  }

  /// Afficher une notification pour une nouvelle demande
  Future<void> showNewRequestNotification({
    required String requestId,
    required String description,
    required String address,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'new_requests_channel',
      'new_request'.tr,
      channelDescription: 'notifications_channel_description'.tr,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(''),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Format message with description and address
    final shortDescription = description.length > 50 
        ? '${description.substring(0, 50)}...' 
        : description;
    final message = '$shortDescription\n${'location'.tr}: $address';
    
    await _notifications.show(
      requestId.hashCode, // ID unique pour la notification
      'new_request'.tr,
      message,
      details,
      payload: requestId, // Passer l'ID de la demande comme payload
    );
  }

  /// Afficher une notification lorsqu'un employé accepte une demande
  Future<void> showEmployeeAcceptedNotification({
    required String requestId,
    required String employeeName,
    required String requestDescription,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'employee_accepted_channel',
      'employee_accepted'.tr,
      channelDescription: 'notifications_channel_description'.tr,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(''),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Format message
    final message = 'employee_accepted_notification_message'.tr.replaceAll('{employee}', employeeName);
    
    await _notifications.show(
      ('employee_accepted_$requestId').hashCode, // ID unique pour la notification
      'employee_accepted'.tr,
      message,
      details,
      payload: requestId, // Passer l'ID de la demande comme payload
    );
  }

  /// Afficher une notification lorsqu'un client accepte un employé
  Future<void> showClientAcceptedEmployeeNotification({
    required String requestId,
    required String clientName,
    required String requestDescription,
  }) async {
    try {
      debugPrint('[LocalNotification] showClientAcceptedEmployeeNotification called');
      debugPrint('[LocalNotification] Request ID: $requestId, Client Name: $clientName');
      
      if (!_initialized) {
        debugPrint('[LocalNotification] Service not initialized, initializing...');
        await initialize();
      }

      final title = 'client_accepted_employee'.tr;
      final message = 'client_accepted_employee_notification_message'.tr.replaceAll('{client}', clientName);
      
      debugPrint('[LocalNotification] Title: $title');
      debugPrint('[LocalNotification] Message: $message');

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'new_requests_channel', // Use same channel as new requests
        title,
        channelDescription: 'notifications_channel_description'.tr,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(message),
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final notificationId = ('client_accepted_employee_$requestId').hashCode;
      debugPrint('[LocalNotification] Showing notification with ID: $notificationId');
      
      await _notifications.show(
        notificationId,
        title,
        message,
        details,
        payload: requestId, // Passer l'ID de la demande comme payload
      );
      
      debugPrint('[LocalNotification] ✅ Notification shown successfully');
    } catch (e, stackTrace) {
      debugPrint('[LocalNotification] ❌ Error showing client accepted employee notification: $e');
      debugPrint('[LocalNotification] Stack trace: $stackTrace');
      rethrow; // Re-throw to let caller handle it
    }
  }

  /// Afficher une notification simple
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? channelId,
    Importance? importance,
    Priority? priority,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // Déterminer le canal et l'importance selon le type de notification
    final String finalChannelId = channelId ?? 'general_channel';
    final Importance finalImportance = importance ?? Importance.defaultImportance;
    final Priority finalPriority = priority ?? Priority.defaultPriority;

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      finalChannelId,
      finalChannelId == 'incoming_calls' 
          ? 'Appels entrants'
          : (finalChannelId == 'new_requests_channel'
              ? 'new_request'.tr
              : (finalChannelId == 'employee_accepted_channel'
                  ? 'employee_accepted'.tr
                  : 'notifications'.tr)),
      channelDescription: finalChannelId == 'incoming_calls'
          ? 'Notifications pour les appels audio entrants'
          : 'general_notifications_channel_description'.tr,
      importance: finalImportance,
      priority: finalPriority,
      showWhen: true,
      playSound: true,
      enableVibration: finalImportance == Importance.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Annuler une notification spécifique
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Annuler toutes les notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Obtenir le nombre de notifications en attente
  Future<int> getPendingNotificationCount() async {
    final List<PendingNotificationRequest> pending = await _notifications.pendingNotificationRequests();
    return pending.length;
  }
}

