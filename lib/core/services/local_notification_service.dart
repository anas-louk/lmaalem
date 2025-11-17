import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'dart:io' show Platform;
import '../constants/app_routes.dart';

/// Service pour gérer les notifications locales dans la barre de statut
class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialiser le service de notifications
  Future<void> initialize() async {
    if (_initialized) return;

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

    // Initialiser le plugin
    final bool? initialized = await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    if (initialized == true) {
      _initialized = true;
      
      // Demander les permissions pour Android 13+
      if (Platform.isAndroid) {
        await _requestAndroidPermissions();
      }
    }
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
    // Naviguer vers l'écran de notifications (employee dashboard)
    // Utiliser Get.offAllNamed pour éviter les problèmes de navigation
    if (response.payload != null) {
      // Si un payload (requestId) est fourni, on peut naviguer vers le détail
      // Sinon, aller au dashboard
      Get.offAllNamed(AppRoutes.employeeDashboard);
    } else {
      Get.offAllNamed(AppRoutes.employeeDashboard);
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

  /// Afficher une notification simple
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'general_channel',
      'notifications'.tr,
      channelDescription: 'general_notifications_channel_description'.tr,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
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

