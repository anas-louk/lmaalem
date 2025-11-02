import 'package:firebase_messaging/firebase_messaging.dart';

/// Service pour gérer les notifications push
class PushNotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initialiser les notifications
  Future<void> initialize() async {
    // Demander la permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Obtenir le token FCM
      String? token = await _messaging.getToken();
      if (token != null) {
        // Sauvegarder le token dans Firestore ou votre backend
        print('FCM Token: $token');
      }
    }

    // Écouter les messages en foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Écouter les clics sur les notifications
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationClick);
  }

  /// Gérer les messages en foreground
  void _handleForegroundMessage(RemoteMessage message) {
    print('Message reçu en foreground: ${message.notification?.title}');
    // Afficher une notification locale ou mettre à jour l'UI
  }

  /// Gérer les clics sur les notifications
  void _handleNotificationClick(RemoteMessage message) {
    print('Notification cliquée: ${message.notification?.title}');
    // Naviguer vers l'écran approprié
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
}

