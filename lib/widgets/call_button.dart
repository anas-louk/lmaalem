/// Call Button Widget
/// 
/// A reusable button widget for initiating calls (audio or video).
/// 
/// Usage:
/// ```dart
/// CallButton(
///   calleeId: 'user123',
///   onCallStarted: () => print('Call started'),
/// )
/// ```
/// 
/// For video call, use long-press or provide video: true:
/// ```dart
/// CallButton(
///   calleeId: 'user123',
///   video: true,
/// )
/// ```

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/call_controller.dart';
import '../utils/call_permissions.dart';
import '../core/constants/app_colors.dart';
import '../core/helpers/snackbar_helper.dart';

class CallButton extends StatelessWidget {
  final String calleeId;
  final bool video;
  final VoidCallback? onCallStarted;
  final Color? iconColor;
  final double? iconSize;

  const CallButton({
    super.key,
    required this.calleeId,
    this.video = false,
    this.onCallStarted,
    this.iconColor,
    this.iconSize,
  });

  Future<void> _handleCall(BuildContext context) async {
    final callController = Get.find<CallController>();
    
    if (callController.hasActiveCall.value) {
      SnackbarHelper.showSnackbar(
        title: 'Call in Progress',
        message: 'Please end the current call before starting a new one.',
        backgroundColor: AppColors.error.withOpacity(0.9),
        colorText: AppColors.white,
      );
      return;
    }

    // Request permissions first
    final hasPermissions = await CallPermissions.requestPermissions(video: video);
    if (!hasPermissions) {
      return; // User denied permissions
    }

    try {
      await callController.startCall(calleeId, video: video);
      onCallStarted?.call();
    } catch (e) {
      SnackbarHelper.showSnackbar(
        title: 'Call Failed',
        message: 'Unable to start call: ${e.toString()}',
        backgroundColor: AppColors.error.withOpacity(0.9),
        colorText: AppColors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        video ? Icons.videocam : Icons.call,
        color: iconColor ?? AppColors.primary,
        size: iconSize ?? 24,
      ),
      onPressed: () => _handleCall(context),
      tooltip: video ? 'Video Call' : 'Audio Call',
    );
  }
}

/// Call Button with Long Press for Video
class CallButtonWithOptions extends StatelessWidget {
  final String calleeId;
  final VoidCallback? onCallStarted;
  final Color? iconColor;
  final double? iconSize;

  const CallButtonWithOptions({
    super.key,
    required this.calleeId,
    this.onCallStarted,
    this.iconColor,
    this.iconSize,
  });

  Future<void> _startCall(BuildContext context, bool video) async {
    final callController = Get.find<CallController>();
    
    if (callController.hasActiveCall.value) {
      SnackbarHelper.showSnackbar(
        title: 'Call in Progress',
        message: 'Please end the current call before starting a new one.',
        backgroundColor: AppColors.error.withOpacity(0.9),
        colorText: AppColors.white,
      );
      return;
    }

    // Request permissions first
    final hasPermissions = await CallPermissions.requestPermissions(video: video);
    if (!hasPermissions) {
      return; // User denied permissions
    }

    try {
      await callController.startCall(calleeId, video: video);
      onCallStarted?.call();
    } catch (e) {
      SnackbarHelper.showSnackbar(
        title: 'Call Failed',
        message: 'Unable to start call: ${e.toString()}',
        backgroundColor: AppColors.error.withOpacity(0.9),
        colorText: AppColors.white,
      );
    }
  }

  void _showCallOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.call, color: AppColors.primary),
              title: const Text('Audio Call'),
              onTap: () {
                Navigator.pop(context);
                _startCall(context, false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: AppColors.primary),
              title: const Text('Video Call'),
              onTap: () {
                Navigator.pop(context);
                _startCall(context, true);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showCallOptions(context),
      child: IconButton(
        icon: Icon(
          Icons.call,
          color: iconColor ?? AppColors.primary,
          size: iconSize ?? 24,
        ),
        onPressed: () => _startCall(context, false),
        tooltip: 'Tap for audio, long-press for options',
      ),
    );
  }
}

