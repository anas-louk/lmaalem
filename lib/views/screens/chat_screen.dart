import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/chat_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../data/models/chat_message_model.dart';
import '../../components/loading_widget.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class ChatScreenArguments {
  final String requestId;
  final String clientId;
  final String employeeId;
  final String requestTitle;
  final String requestStatus;
  final String? clientName;
  final String? employeeName;
  final String? employeeUserId;

  const ChatScreenArguments({
    required this.requestId,
    required this.clientId,
    required this.employeeId,
    required this.requestTitle,
    required this.requestStatus,
    this.clientName,
    this.employeeName,
    this.employeeUserId,
  });
}

class ChatScreen extends StatefulWidget {
  final ChatScreenArguments args;

  const ChatScreen({super.key, required this.args});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatController _chatController = Get.put(ChatController());
  final AuthController _authController = Get.find<AuthController>();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Worker? _messagesWorker;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _messagesWorker = ever<List<ChatMessageModel>>(
      _chatController.messages,
      (_) => _scrollToBottom(),
    );
  }

  void _initializeChat() {
    final args = widget.args;
    final clientName = args.clientName ?? 'Client';
    final employeeName = args.employeeName ?? 'Employé';

    _chatController.initChat(
      requestId: args.requestId,
      requestTitle: args.requestTitle,
      clientId: args.clientId,
      clientName: clientName,
      employeeId: args.employeeId,
      employeeName: employeeName,
      employeeUserId: args.employeeUserId,
      requestStatus: args.requestStatus,
      allowCreateIfMissing: true,
    );
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _messagesWorker?.dispose();
    _scrollController.dispose();
    _textController.dispose();
    Get.delete<ChatController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _authController.currentUser.value;
    final args = widget.args;
    final isClient = user?.id == args.clientId;

    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Text(
            _chatController.thread.value?.requestTitle ?? args.requestTitle,
          ),
        ),
      ),
      body: Obx(() {
        if (_chatController.isLoading.value) {
          return const LoadingWidget();
        }

        final thread = _chatController.thread.value;
        if (thread == null) {
          return _buildUnavailableState();
        }

        final messages = _chatController.messages;
        return Column(
          children: [
            if (!thread.isActive)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: AppColors.warning.withOpacity(0.15),
                child: Text(
                  'chat_disabled_request_finished'.tr,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Expanded(
              child: messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMine = message.senderId == user?.id;
                        return Align(
                          alignment: isMine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.7,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isMine ? AppColors.primary : AppColors.surface,
                              borderRadius: BorderRadius.circular(18).copyWith(
                                bottomRight: Radius.circular(isMine ? 0 : 18),
                                bottomLeft: Radius.circular(isMine ? 18 : 0),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isMine)
                                  Text(
                                    isClient ? thread.employeeName : thread.clientName,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: isMine
                                          ? AppColors.white.withOpacity(0.9)
                                          : AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                if (!isMine) const SizedBox(height: 4),
                                Text(
                                  message.content,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: isMine ? AppColors.white : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _formatTime(message.createdAt),
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontSize: 11,
                                    color: isMine
                                        ? AppColors.white.withOpacity(0.7)
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            _buildComposer(thread.isActive),
          ],
        );
      }),
    );
  }

  Widget _buildComposer(bool isActive) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                enabled: isActive,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'type_message_hint'.tr,
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 48,
              width: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                ),
                onPressed: (!isActive || _chatController.isSending.value)
                    ? null
                    : _handleSendMessage,
                child: _chatController.isSending.value
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'chat_empty_state'.tr,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnavailableState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'chat_not_available'.tr,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _chatController.sendMessage(text);
    _textController.clear();
  }

  String _formatTime(DateTime dateTime) {
    final hours = dateTime.hour.toString().padLeft(2, '0');
    final minutes = dateTime.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
}


