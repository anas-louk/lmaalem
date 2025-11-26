import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../controllers/auth_controller.dart';
import '../../data/models/chat_thread_model.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/repositories/chat_repository.dart';
import '../../core/constants/app_routes.dart' as AppRoutes;
import 'local_notification_service.dart';

/// Service global pour écouter les messages de chat et envoyer des notifications
/// Ce service reste actif même quand l'utilisateur n'est pas sur l'écran de chat
class ChatNotificationService {
  static final ChatNotificationService _instance = ChatNotificationService._internal();
  factory ChatNotificationService() => _instance;
  ChatNotificationService._internal();

  final ChatRepository _chatRepository = ChatRepository();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Streams actifs pour chaque thread
  final Map<String, StreamSubscription<List<ChatMessageModel>>> _activeSubscriptions = {};
  final Map<String, ChatThreadModel> _activeThreads = {};
  
  // Pour suivre les messages déjà notifiés par thread
  final Map<String, Set<String>> _notifiedMessageIds = {};
  
  // Pour suivre le requestId actuellement affiché dans l'écran de chat
  String? _currentChatRequestId;
  
  bool _isInitialized = false;

  /// Initialiser le service et commencer à écouter les threads de chat
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('[ChatNotificationService] Déjà initialisé');
      return;
    }

    try {
      final authController = Get.find<AuthController>();
      
      // Écouter les changements d'utilisateur
      ever(authController.currentUser, (user) {
        if (user != null) {
          _startListeningToUserChats(user.id);
        } else {
          _stopAllListeners();
        }
      });

      // Si l'utilisateur est déjà connecté, démarrer l'écoute
      final currentUser = authController.currentUser.value;
      if (currentUser != null) {
        _startListeningToUserChats(currentUser.id);
      }

      _isInitialized = true;
      debugPrint('[ChatNotificationService] ✅ Service initialisé');
    } catch (e) {
      debugPrint('[ChatNotificationService] ❌ Erreur lors de l\'initialisation: $e');
    }
  }

  /// Démarrer l'écoute des threads de chat pour un utilisateur
  void _startListeningToUserChats(String userId) async {
    try {
      debugPrint('[ChatNotificationService] Démarrage de l\'écoute pour l\'utilisateur: $userId');
      
      // Écouter tous les threads de chat où l'utilisateur est impliqué
      // En tant que client ou employé
      _firestore
          .collection('chats')
          .where('isActive', isEqualTo: true)
          .snapshots()
          .listen((snapshot) {
        _handleChatThreadsUpdate(snapshot, userId);
      });
    } catch (e) {
      debugPrint('[ChatNotificationService] ❌ Erreur lors du démarrage de l\'écoute: $e');
    }
  }

  /// Gérer les mises à jour des threads de chat
  void _handleChatThreadsUpdate(QuerySnapshot snapshot, String userId) {
    final currentThreadIds = <String>{};
    
    for (final doc in snapshot.docs) {
      try {
        final thread = ChatThreadModel.fromDocument(doc as DocumentSnapshot);
        final threadId = thread.requestId;
        currentThreadIds.add(threadId);

        // Vérifier si l'utilisateur est impliqué dans ce thread
        final isInvolved = thread.clientId == userId || 
                          thread.employeeId == userId ||
                          (thread.employeeUserId != null && thread.employeeUserId == userId);
        
        if (!isInvolved) {
          continue; // Ignorer les threads où l'utilisateur n'est pas impliqué
        }

        // Si le thread n'est pas encore écouté, démarrer l'écoute
        if (!_activeSubscriptions.containsKey(threadId)) {
          _activeThreads[threadId] = thread;
          _notifiedMessageIds[threadId] = <String>{};
          _listenToThreadMessages(threadId, userId);
        }
      } catch (e) {
        debugPrint('[ChatNotificationService] ❌ Erreur lors du traitement du thread: $e');
      }
    }

    // Arrêter l'écoute des threads qui ne sont plus actifs
    final threadsToRemove = _activeSubscriptions.keys
        .where((threadId) => !currentThreadIds.contains(threadId))
        .toList();
    
    for (final threadId in threadsToRemove) {
      _stopListeningToThread(threadId);
    }
  }

  /// Écouter les messages d'un thread spécifique
  void _listenToThreadMessages(String requestId, String userId) {
    debugPrint('[ChatNotificationService] Démarrage de l\'écoute pour le thread: $requestId');
    
    final subscription = _chatRepository.streamMessages(requestId).listen(
      (messageList) {
        _handleNewMessages(requestId, messageList, userId);
      },
      onError: (error) {
        debugPrint('[ChatNotificationService] ❌ Erreur dans le stream pour $requestId: $error');
      },
    );

    _activeSubscriptions[requestId] = subscription;
  }

  /// Gérer les nouveaux messages reçus
  void _handleNewMessages(String requestId, List<ChatMessageModel> messages, String userId) {
    final notifiedIds = _notifiedMessageIds[requestId] ?? <String>{};
    final thread = _activeThreads[requestId];
    
    if (thread == null) {
      debugPrint('[ChatNotificationService] ⚠️ Thread $requestId non trouvé');
      return;
    }

    for (final message in messages) {
      // Ne notifier que si :
      // 1. Le message n'a pas encore été notifié
      // 2. Le message n'est pas de l'utilisateur actuel
      // 3. L'utilisateur n'est pas sur l'écran de chat pour ce requestId
      if (!notifiedIds.contains(message.id) &&
          message.senderId != userId &&
          !_isUserOnChatScreen(requestId)) {
        notifiedIds.add(message.id);
        _notifiedMessageIds[requestId] = notifiedIds;
        _sendNotificationForMessage(message, thread);
      }
    }
  }

  /// Vérifier si l'utilisateur est actuellement sur l'écran de chat pour ce requestId
  bool _isUserOnChatScreen(String requestId) {
    try {
      final currentRoute = Get.currentRoute;
      if (currentRoute != AppRoutes.AppRoutes.chat) {
        return false;
      }
      
      // Vérifier si le requestId correspond à celui actuellement affiché
      return _currentChatRequestId == requestId;
    } catch (e) {
      return false;
    }
  }

  /// Mettre à jour le requestId actuellement affiché dans l'écran de chat
  void setCurrentChatRequestId(String? requestId) {
    _currentChatRequestId = requestId;
    debugPrint('[ChatNotificationService] RequestId actuel mis à jour: $requestId');
  }

  /// Envoyer une notification pour un nouveau message
  void _sendNotificationForMessage(ChatMessageModel message, ChatThreadModel thread) async {
    try {
      // Déterminer le nom de l'expéditeur
      String senderName = 'Quelqu\'un';
      if (message.senderRole == 'client') {
        senderName = thread.clientName;
      } else if (message.senderRole == 'employee') {
        senderName = thread.employeeName;
      }

      // Tronquer le contenu du message pour la notification
      final shortContent = message.content.length > 100 
        ? '${message.content.substring(0, 100)}...' 
        : message.content;

      // Afficher la notification locale
      final notificationService = LocalNotificationService();
      await notificationService.showNotification(
        id: message.id.hashCode,
        title: senderName,
        body: shortContent,
        payload: thread.requestId,
        channelId: 'chat_messages_channel',
        importance: Importance.high,
        priority: Priority.high,
      );

      debugPrint('[ChatNotificationService] ✅ Notification envoyée pour le message ${message.id} du thread ${thread.requestId}');
    } catch (e) {
      debugPrint('[ChatNotificationService] ❌ Erreur lors de l\'envoi de la notification: $e');
    }
  }

  /// Arrêter l'écoute d'un thread spécifique
  void _stopListeningToThread(String requestId) {
    final subscription = _activeSubscriptions.remove(requestId);
    subscription?.cancel();
    _activeThreads.remove(requestId);
    _notifiedMessageIds.remove(requestId);
    debugPrint('[ChatNotificationService] Arrêt de l\'écoute pour le thread: $requestId');
  }

  /// Arrêter tous les listeners
  void _stopAllListeners() {
    for (final subscription in _activeSubscriptions.values) {
      subscription.cancel();
    }
    _activeSubscriptions.clear();
    _activeThreads.clear();
    _notifiedMessageIds.clear();
    _currentChatRequestId = null;
    debugPrint('[ChatNotificationService] Tous les listeners arrêtés');
  }

  /// Arrêter le service
  void dispose() {
    _stopAllListeners();
    _isInitialized = false;
    debugPrint('[ChatNotificationService] Service arrêté');
  }
}

