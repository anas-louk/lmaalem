import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/chat_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../widgets/call_button.dart';
import '../../data/models/chat_message_model.dart';
import '../../components/loading_widget.dart';
import '../../components/indrive_app_bar.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/chat_notification_service.dart';

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

    // Notifier le service que l'utilisateur est sur l'écran de chat
    ChatNotificationService().setCurrentChatRequestId(args.requestId);

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
    // Notifier le service que l'utilisateur a quitté l'écran de chat
    ChatNotificationService().setCurrentChatRequestId(null);
    
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
      backgroundColor: AppColors.night,
      appBar: _buildAppBar(),
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
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.warning.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'chat_disabled_request_finished'.tr,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMine = message.senderId == user?.id;
                        return Align(
                          alignment: isMine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: EdgeInsets.only(
                              bottom: 12,
                              left: isMine ? 40 : 0,
                              right: isMine ? 0 : 40,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.7,
                            ),
                            decoration: BoxDecoration(
                              gradient: isMine
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppColors.primary,
                                        AppColors.primaryDark,
                                      ],
                                    )
                                  : null,
                              color: isMine ? null : AppColors.nightSurface,
                              borderRadius: BorderRadius.circular(20).copyWith(
                                bottomRight: Radius.circular(isMine ? 4 : 20),
                                bottomLeft: Radius.circular(isMine ? 20 : 4),
                                topLeft: const Radius.circular(20),
                                topRight: const Radius.circular(20),
                              ),
                              border: isMine
                                  ? null
                                  : Border.all(
                                      color: Colors.white10,
                                      width: 1,
                                    ),
                              boxShadow: [
                                BoxShadow(
                                  color: isMine
                                      ? AppColors.primary.withOpacity(0.3)
                                      : Colors.black.withOpacity(0.3),
                                  blurRadius: 12,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isMine)
                                  Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.secondary,
                                              AppColors.secondaryDark,
                                            ],
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            (isClient ? thread.employeeName : thread.clientName)
                                                .isNotEmpty
                                                ? (isClient ? thread.employeeName : thread.clientName)[0].toUpperCase()
                                                : 'U',
                                            style: AppTextStyles.bodySmall.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isClient ? thread.employeeName : thread.clientName,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                if (!isMine) const SizedBox(height: 8),
                                Text(
                                  message.content,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: isMine ? Colors.white : Colors.white,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      _formatTime(message.createdAt),
                                      style: AppTextStyles.bodySmall.copyWith(
                                        fontSize: 10,
                                        color: isMine
                                            ? Colors.white70
                                            : Colors.white54,
                                      ),
                                    ),
                                    if (isMine) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.done_all_rounded,
                                        size: 14,
                                        color: Colors.white70,
                                      ),
                                    ],
                                  ],
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
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.nightSurface,
          border: Border(
            top: BorderSide(
              color: Colors.white10,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.nightSecondary,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white10,
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _textController,
                    enabled: isActive,
                    minLines: 1,
                    maxLines: 4,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      hintText: 'type_message_hint'.tr,
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white54,
                      ),
                      filled: false,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: (!isActive || _chatController.isSending.value)
                        ? [
                            AppColors.grey,
                            AppColors.greyDark,
                          ]
                        : [
                            AppColors.primary,
                            AppColors.primaryDark,
                          ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: (!isActive || _chatController.isSending.value)
                      ? null
                      : [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 12,
                            spreadRadius: 0,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: (!isActive || _chatController.isSending.value)
                        ? null
                        : _handleSendMessage,
                    borderRadius: BorderRadius.circular(24),
                    child: Center(
                      child: _chatController.isSending.value
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 48,
                color: AppColors.primaryLight,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'chat_empty_state'.tr,
              textAlign: TextAlign.center,
              style: AppTextStyles.h4.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Commencez la conversation',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white70,
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
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.error.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'chat_not_available'.tr,
              textAlign: TextAlign.center,
              style: AppTextStyles.h4.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Le chat n\'est pas disponible pour cette demande',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white70,
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

  String _getRemoteUserId() {
    final user = _authController.currentUser.value;
    if (user == null) return '';

    final args = widget.args;
    return user.id == args.clientId 
        ? (args.employeeUserId ?? args.employeeId)
        : args.clientId;
  }

  PreferredSizeWidget _buildAppBar() {
    return _ReactiveAppBar(
      chatController: _chatController,
      defaultTitle: widget.args.requestTitle,
      getRemoteUserId: _getRemoteUserId,
    );
  }
}

class _ReactiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  final ChatController chatController;
  final String defaultTitle;
  final String Function() getRemoteUserId;

  const _ReactiveAppBar({
    required this.chatController,
    required this.defaultTitle,
    required this.getRemoteUserId,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => InDriveAppBar(
        title: chatController.thread.value?.requestTitle ?? defaultTitle,
        actions: [
          // Audio Call Button
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: CallButton(
              calleeId: getRemoteUserId(),
              video: false,
            ),
          ),
          // Video Call Button
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: CallButton(
              calleeId: getRemoteUserId(),
              video: true,
            ),
          ),
        ],
      ),
    );
  }
}



