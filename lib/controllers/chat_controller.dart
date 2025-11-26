import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import '../data/models/chat_thread_model.dart';
import '../data/models/chat_message_model.dart';
import '../data/repositories/chat_repository.dart';
import 'auth_controller.dart';
import '../core/helpers/snackbar_helper.dart';
import '../core/constants/app_routes.dart' as AppRoutes;
import '../core/services/local_notification_service.dart';

class ChatController extends GetxController {
  final ChatRepository _chatRepository = ChatRepository();

  final Rx<ChatThreadModel?> thread = Rx<ChatThreadModel?>(null);
  final RxList<ChatMessageModel> messages = <ChatMessageModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSending = false.obs;
  final RxString errorMessage = ''.obs;

  StreamSubscription<List<ChatMessageModel>>? _messagesSubscription;
  
  // Pour suivre les messages déjà notifiés
  final Set<String> _notifiedMessageIds = {};
  
  // Pour suivre le requestId actuel pour vérifier si on est sur l'écran de chat
  String? _currentRequestId;

  Future<void> initChat({
    required String requestId,
    required String requestTitle,
    required String clientId,
    required String clientName,
    required String employeeId,
    required String employeeName,
    String? employeeUserId,
    required String requestStatus,
    bool allowCreateIfMissing = false,
  }) async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      var currentThread = await _chatRepository.getThreadByRequestId(requestId);

      if (currentThread == null && allowCreateIfMissing) {
        currentThread = await _chatRepository.createOrActivateThread(
          requestId: requestId,
          requestTitle: requestTitle,
          clientId: clientId,
          clientName: clientName,
          employeeId: employeeId,
          employeeName: employeeName,
          employeeUserId: employeeUserId,
          requestStatus: requestStatus,
        );
      } else if (currentThread != null &&
          !currentThread.isActive &&
          requestStatus.toLowerCase() == 'accepted') {
        currentThread = await _chatRepository.createOrActivateThread(
          requestId: requestId,
          requestTitle: requestTitle,
          clientId: clientId,
          clientName: clientName,
          employeeId: employeeId,
          employeeName: employeeName,
          employeeUserId: employeeUserId,
          requestStatus: requestStatus,
        );
      }

      thread.value = currentThread;
      isLoading.value = false;

      if (currentThread != null) {
        _listenToMessages(currentThread.requestId);
      }
    } catch (e) {
      errorMessage.value = e.toString();
      isLoading.value = false;
    }
  }

  void _listenToMessages(String requestId) {
    _messagesSubscription?.cancel();
    _currentRequestId = requestId;
    _notifiedMessageIds.clear(); // Réinitialiser pour le nouveau thread
    
    _messagesSubscription =
        _chatRepository.streamMessages(requestId).listen((messageList) {
      messages.assignAll(messageList);
      
      // Détecter les nouveaux messages (pas encore notifiés)
      final authController = Get.find<AuthController>();
      final user = authController.currentUser.value;
      if (user != null) {
        for (final message in messageList) {
          // Ne notifier que si :
          // 1. Le message n'a pas encore été notifié
          // 2. Le message n'est pas de l'utilisateur actuel
          // 3. L'utilisateur n'est pas sur l'écran de chat pour ce requestId
          if (!_notifiedMessageIds.contains(message.id) &&
              message.senderId != user.id &&
              !_isUserOnChatScreen(requestId)) {
            _notifiedMessageIds.add(message.id);
            _handleNewMessage(message, requestId);
          }
        }
      }
      // Scroll handled at widget level.
    });
  }
  
  /// Vérifier si l'utilisateur est actuellement sur l'écran de chat pour ce requestId
  bool _isUserOnChatScreen(String requestId) {
    try {
      final currentRoute = Get.currentRoute;
      if (currentRoute != AppRoutes.AppRoutes.chat) {
        return false;
      }
      
      // Vérifier si le requestId correspond au thread actuel
      return _currentRequestId == requestId;
    } catch (e) {
      return false;
    }
  }
  
  /// Gérer un nouveau message reçu (envoyer notification)
  void _handleNewMessage(ChatMessageModel message, String requestId) async {
    try {
      final authController = Get.find<AuthController>();
      final user = authController.currentUser.value;
      if (user == null) return;

      final currentThread = thread.value;
      if (currentThread == null) return;

      // Déterminer le nom de l'expéditeur
      String senderName = 'Quelqu\'un';
      if (message.senderRole == 'client') {
        senderName = currentThread.clientName;
      } else if (message.senderRole == 'employee') {
        senderName = currentThread.employeeName;
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
        payload: requestId,
        channelId: 'chat_messages_channel',
        importance: Importance.high,
        priority: Priority.high,
      );

      debugPrint('[ChatController] ✅ Notification envoyée pour le message ${message.id}');
    } catch (e) {
      debugPrint('[ChatController] ❌ Erreur lors de l\'envoi de la notification: $e');
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final currentThread = thread.value;
    if (currentThread == null) {
      errorMessage.value = 'chat_not_available'.tr;
      SnackbarHelper.showInfo(errorMessage.value);
      return;
    }
    if (!currentThread.isActive) {
      errorMessage.value = 'chat_disabled_request_finished'.tr;
      SnackbarHelper.showInfo(errorMessage.value);
      return;
    }

    final authController = Get.find<AuthController>();
    final user = authController.currentUser.value;
    if (user == null) {
      errorMessage.value = 'Utilisateur non authentifié';
      return;
    }

    final senderRole =
        user.id == currentThread.clientId ? 'client' : 'employee';

    try {
      isSending.value = true;
      await _chatRepository.sendMessage(
        requestId: currentThread.requestId,
        senderId: user.id,
        senderRole: senderRole,
        content: text,
      );
    } catch (e) {
      errorMessage.value = e.toString();
      SnackbarHelper.showError(errorMessage.value);
    } finally {
      isSending.value = false;
    }
  }

  @override
  void onClose() {
    _messagesSubscription?.cancel();
    _currentRequestId = null;
    _notifiedMessageIds.clear();
    super.onClose();
  }
}


