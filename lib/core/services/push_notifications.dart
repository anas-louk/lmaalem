import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../constants/app_routes.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/call_controller.dart';
import '../firebase/firebase_init.dart';
import 'local_notification_service.dart';
import '../helpers/snackbar_helper.dart';

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
      // Obtenir le token FCM - MUST save for background notifications
      String? token = await _messaging.getToken();
      if (token != null) {
        debugPrint('[FCM] FCM Token: $token');
        // Save token will be called after user login in AuthController
      }

      // Listen for token refresh and save to Firestore
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

    // Écouter les messages en foreground (app open)
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Écouter les clics sur les notifications (when app is opened from background state)
    // Note: This only works when app was in background, not terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationClick);
    
    // IMPORTANT: For background (minimized) notifications to work:
    // 1. FCM tokens are saved to Firestore (done in AuthController)
    // 2. Server-side Cloud Functions MUST send FCM messages when events occur
    // 3. Firestore streams work for foreground, FCM works for background
  }

  /// Gérer les messages en foreground et background (app running but minimized)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[FCM] Message reçu: ${message.notification?.title}');
    debugPrint('[FCM] Data: ${message.data}');
    debugPrint('[FCM] MessageId: ${message.messageId}');
    
    // Handle incoming audio call notifications
    if (message.data['type'] == 'incoming_audio_call') {
      _handleIncomingAudioCall(message);
      return;
    }
    
    // Show local notification for other message types
    if (message.notification != null) {
      await _localNotificationService.showNotification(
        id: message.hashCode,
        title: message.notification!.title ?? 'Notification',
        body: message.notification!.body ?? '',
        payload: message.data['requestId'] ?? message.data['type'],
      );
    }
  }

  /// Handle incoming audio call notification
  void _handleIncomingAudioCall(RemoteMessage message) {
    final callId = message.data['callId'];
    final callerId = message.data['callerId'];
    final callerName = message.data['callerName'] ?? 'Someone';

    if (callId == null || callerId == null) {
      debugPrint('[FCM] Invalid incoming call data: missing callId or callerId');
      return;
    }

    debugPrint('[FCM] Incoming audio call: callId=$callId, callerId=$callerId');

    try {
      // Show snackbar notification using SnackbarHelper (handles overlay availability)
      SnackbarHelper.showInfo(
        'Call from $callerName',
        title: 'Incoming Call',
      );

      // Navigate to incoming call screen
      // Use a delayed navigation to ensure GetX is ready
      Future.delayed(const Duration(milliseconds: 100), () {
        _navigateToIncomingCall(callId, callerId);
      });
    } catch (e) {
      debugPrint('[FCM] Error handling incoming call: $e');
    }
  }

  /// Navigate to incoming call screen with retry logic
  void _navigateToIncomingCall(String callId, String callerId, {int retryCount = 0}) {
    try {
      // Check if GetX is ready
      if (!Get.isRegistered<CallController>()) {
        if (retryCount < 5) {
          debugPrint('[FCM] CallController not registered yet, retrying... (attempt ${retryCount + 1})');
          Future.delayed(Duration(milliseconds: 200 * (retryCount + 1)), () {
            _navigateToIncomingCall(callId, callerId, retryCount: retryCount + 1);
          });
          return;
        } else {
          debugPrint('[FCM] CallController not available after retries, cannot handle incoming call');
          return;
        }
      }

      final callController = Get.find<CallController>();
      callController.handleIncomingCallFromFCM(
        callId: callId,
        callerId: callerId,
        isVideo: false, // Always false for audio calls
      );
    } catch (e) {
      debugPrint('[FCM] Error navigating to incoming call: $e');
      if (retryCount < 5) {
        Future.delayed(Duration(milliseconds: 200 * (retryCount + 1)), () {
          _navigateToIncomingCall(callId, callerId, retryCount: retryCount + 1);
        });
      }
    }
  }

  /// Gérer les clics sur les notifications
  void _handleNotificationClick(RemoteMessage message) {
    debugPrint('[FCM] Notification cliquée: ${message.notification?.title}');
    debugPrint('[FCM] Data: ${message.data}');
    
    final type = message.data['type'] ?? 'default';

    // Handle incoming audio call notification click
    // This is triggered when user taps the system notification (app was backgrounded/closed)
    if (type == 'incoming_audio_call') {
      final callId = message.data['callId'];
      final callerId = message.data['callerId'];
      final callerName = message.data['callerName'] ?? 'Someone';

      if (callId != null && callerId != null) {
        debugPrint('[FCM] Opening incoming call screen from notification click');
        debugPrint('[FCM] Call details: callId=$callId, callerId=$callerId, callerName=$callerName');
        // Use the same retry logic as foreground handler
        Future.delayed(const Duration(milliseconds: 100), () {
          _navigateToIncomingCall(callId, callerId);
        });
      } else {
        debugPrint('[FCM] Invalid incoming call data in notification click: missing callId or callerId');
      }
      return;
    }

    // Navigate based on other notification types
    final requestId = message.data['requestId'];

    // Les types attendus correspondent à ton JSON FCM : "new_request" et "employee_accepted"
    if (requestId != null && type == 'new_request') {
      // Nouvelle demande : aller au détail de la demande (employé)
      Get.toNamed(AppRoutes.requestDetail, arguments: requestId);
    } else if (requestId != null && type == 'employee_accepted') {
      // Un employé a accepté : aller au détail de la demande (client)
      Get.toNamed(AppRoutes.requestDetail, arguments: requestId);
    } else if (type == 'new_request') {
      // Sans requestId on envoie au centre de notifications employé
      Get.toNamed(AppRoutes.notifications);
    } else {
      // Cas par défaut : dashboard
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

/// Handler FCM exécuté lorsque un message arrive alors que l'app est en arrière‑plan
/// ou terminée. Doit être une fonction top‑level.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] (background) Message reçu: ${message.notification?.title}');
  debugPrint('[FCM] (background) Data: ${message.data}');
  debugPrint('[FCM] (background) MessageId: ${message.messageId}');

  try {
    // Initialiser Firebase dans l'isolat de fond
    await FirebaseInit.initialize();

    // Initialiser les notifications locales (idempotent)
    final localService = LocalNotificationService();
    await localService.initialize();

    // Handle incoming audio call notifications
    if (message.data['type'] == 'incoming_audio_call') {
      final callId = message.data['callId'];
      final callerId = message.data['callerId'];
      final callerName = message.data['callerName'] ?? 'Someone';

      if (callId != null && callerId != null) {
        debugPrint('[FCM] (background) Incoming audio call: callId=$callId, callerId=$callerId');
        
        // Always show a local notification for incoming calls to ensure it appears
        // even if the system notification doesn't show
        await localService.showNotification(
          id: callId.hashCode,
          title: message.notification?.title ?? 'Incoming Call',
          body: message.notification?.body ?? 'Call from $callerName',
          payload: callId,
          channelId: 'incoming_calls',
          importance: Importance.high,
          priority: Priority.high,
        );
      }
      return;
    }

    // Pour les autres types de messages, toujours afficher une notification locale
    // même si le message FCM a un bloc "notification" (pour garantir l'affichage)
    final notificationType = message.data['type'] ?? 'default';
    final requestId = message.data['requestId'];
    
    // Déterminer le titre, le corps et le canal de la notification
    String title;
    String body;
    String? channelId;
    Importance? importance;
    Priority? priority;
    
    if (message.notification != null) {
      // Utiliser les valeurs du bloc notification si disponibles
      title = message.notification!.title ?? 'Notification';
      body = message.notification!.body ?? '';
    } else {
      // Créer un titre et un corps basés sur le type de message
      switch (notificationType) {
        case 'new_request':
          title = 'Nouvelle demande';
          body = 'Une nouvelle demande de service est disponible';
          channelId = 'new_requests_channel';
          importance = Importance.high;
          priority = Priority.high;
          break;
        case 'employee_accepted':
          title = 'Demande acceptée';
          body = 'Un employé a accepté votre demande';
          channelId = 'employee_accepted_channel';
          importance = Importance.high;
          priority = Priority.high;
          break;
        default:
          title = 'Notification';
          body = 'Vous avez une nouvelle notification';
          channelId = 'general_channel';
          importance = Importance.defaultImportance;
          priority = Priority.defaultPriority;
      }
    }
    
    // Déterminer le canal selon le type si non spécifié
    if (channelId == null) {
      switch (notificationType) {
        case 'new_request':
          channelId = 'new_requests_channel';
          importance = Importance.high;
          priority = Priority.high;
          break;
        case 'employee_accepted':
          channelId = 'employee_accepted_channel';
          importance = Importance.high;
          priority = Priority.high;
          break;
        default:
          channelId = 'general_channel';
      }
    }
    
    // Toujours afficher une notification locale pour garantir l'affichage
    await localService.showNotification(
      id: message.messageId?.hashCode ?? message.hashCode,
      title: title,
      body: body,
      payload: requestId ?? notificationType,
      channelId: channelId,
      importance: importance,
      priority: priority,
    );
    
    debugPrint('[FCM] (background) ✅ Notification locale affichée: $title');
  } catch (e, stackTrace) {
    debugPrint('[FCM] (background) ❌ Erreur lors du traitement du message: $e');
    debugPrint('[FCM] (background) Stack trace: $stackTrace');
  }
}