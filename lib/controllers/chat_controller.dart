import 'dart:async';
import 'package:get/get.dart';
import '../data/models/chat_thread_model.dart';
import '../data/models/chat_message_model.dart';
import '../data/repositories/chat_repository.dart';
import 'auth_controller.dart';
import '../core/helpers/snackbar_helper.dart';

class ChatController extends GetxController {
  final ChatRepository _chatRepository = ChatRepository();

  final Rx<ChatThreadModel?> thread = Rx<ChatThreadModel?>(null);
  final RxList<ChatMessageModel> messages = <ChatMessageModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSending = false.obs;
  final RxString errorMessage = ''.obs;

  StreamSubscription<List<ChatMessageModel>>? _messagesSubscription;

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
    _messagesSubscription =
        _chatRepository.streamMessages(requestId).listen((messageList) {
      messages.assignAll(messageList);
      // Scroll handled at widget level.
    });
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
    super.onClose();
  }
}


