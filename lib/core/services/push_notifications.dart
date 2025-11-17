import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_routes.dart';
import '../../controllers/auth_controller.dart';
import 'local_notification_service.dart';

/// Service pour gérer les notifications push
class PushNotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final LocalNotificationService _localNotificationService = LocalNotificationService();

  /// Initialiser les notifications
  Future<void> initialize() async {
    // Demander la permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // Obtenir le token FCM
      String? token = await _messaging.getToken();
      if (token != null) {
        debugPrint('[FCM] FCM Token: $token');
        // Save token will be called after user login in AuthController
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('[FCM] Token refreshed: $newToken');
        // Update token in Firestore when it refreshes
        try {
          final authController = Get.find<AuthController>();
          final currentUser = authController.currentUser.value;
          if (currentUser != null) {
            await saveTokenToFirestore(currentUser.id, newToken);
          }
        } catch (e) {
          debugPrint('[FCM] Error updating token on refresh: $e');
        }
      });
    }

    // Initialize local notifications for foreground messages
    await _localNotificationService.initialize();

    // Écouter les messages en foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Écouter les clics sur les notifications (when app is opened from terminated state)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationClick);
    
    // Check if app was opened from a notification (terminated state)
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationClick(initialMessage);
    }
  }

  /// Gérer les messages en foreground
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[FCM] Message reçu en foreground: ${message.notification?.title}');
    debugPrint('[FCM] Data: ${message.data}');
    
    // Show local notification for foreground messages
    if (message.notification != null) {
      await _localNotificationService.showNotification(
        id: message.hashCode,
        title: message.notification!.title ?? 'Notification',
        body: message.notification!.body ?? '',
        payload: message.data['requestId'] ?? message.data['type'],
      );
    }
  }

  /// Gérer les clics sur les notifications
  void _handleNotificationClick(RemoteMessage message) {
    debugPrint('[FCM] Notification cliquée: ${message.notification?.title}');
    debugPrint('[FCM] Data: ${message.data}');
    
    // Navigate based on notification type
    final requestId = message.data['requestId'];
    final type = message.data['type'] ?? 'default';
    
    if (requestId != null) {
      // Navigate to request detail
      Get.toNamed(AppRoutes.requestDetail, arguments: requestId);
    } else if (type == 'new_request') {
      // Navigate to notifications screen for employees
      Get.toNamed(AppRoutes.notifications);
    } else {
      // Navigate to dashboard
      Get.offAllNamed(AppRoutes.home);
    }
  }

  /// Obtenir le token FCM
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  /// Supprimer le token
  Future<void> deleteToken() async {
    await _messaging.deleteToken();
  }

  /// S'abonner à un topic
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  /// Se désabonner d'un topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }

  /// Sauvegarder le token FCM dans Firestore
  Future<void> saveTokenToFirestore(String userId, String token) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[FCM] Token saved to Firestore for user $userId');
    } catch (e) {
      debugPrint('[FCM] Error saving token to Firestore: $e');
      // Try to set if update fails (document might not exist)
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .set({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('[FCM] Token set (with merge) to Firestore for user $userId');
      } catch (e2) {
        debugPrint('[FCM] Error setting token to Firestore: $e2');
      }
    }
  }

  /// Supprimer le token FCM de Firestore
  Future<void> removeTokenFromFirestore(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'fcmToken': FieldValue.delete(),
      });
      debugPrint('[FCM] Token removed from Firestore for user $userId');
    } catch (e) {
      debugPrint('[FCM] Error removing token from Firestore: $e');
    }
  }
}

