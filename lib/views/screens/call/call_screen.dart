/// Active Call Screen
/// 
/// Displays the active call with video/audio streams and controls.
/// 
/// Testing:
/// 1. Start a call from User A -> User B accepts
/// 2. Both users should see CallScreen with:
///    - Video: Remote video (large) + local preview (small overlay)
///    - Audio: Avatar + name + connection status
/// 3. Timer should start when call is accepted
/// 4. Controls: Mute, Camera (video), Speaker, End Call
/// 5. End call -> updates Firestore status to 'ended' and pops screen
/// 
/// Implementation Notes:
/// - Uses RTCVideoRenderer for video streams
/// - Renderers are properly initialized and disposed
/// - Timer tracks call duration
/// - Connection state displayed based on CallController.currentStatus

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../controllers/call_controller.dart';
import '../../../models/call_session.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../../utils/call_timer.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class CallScreenArguments {
  final String callId;
  final String remoteUserId;
  final bool isVideo;

  const CallScreenArguments({
    required this.callId,
    required this.remoteUserId,
    required this.isVideo,
  });
}

class CallScreen extends StatefulWidget {
  final CallScreenArguments args;

  const CallScreen({super.key, required this.args});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final CallController _callController = Get.find<CallController>();
  final UserRepository _userRepository = UserRepository();
  final EmployeeRepository _employeeRepository = EmployeeRepository();
  final CallTimer _callTimer = CallTimer();

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  String? _remoteUserName;
  String? _remoteUserAvatar;
  bool _isCameraOn = true;
  bool _isLocalVideoInitialized = false;
  bool _isRemoteVideoInitialized = false;
  Timer? _streamCheckTimer;
  Timer? _timerUpdateTimer;
  String _callDurationText = '00:00';

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
    _loadRemoteUserInfo();
    _setupCallListeners();
  }

  Future<void> _initializeRenderers() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      
      // Setup local stream
      _updateLocalStream();
      
      // Setup remote stream
      _updateRemoteStream();
      
      // Periodic check for streams
      _streamCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        _updateLocalStream();
        _updateRemoteStream();
      });
    } catch (e) {
      print('[CallScreen] Error initializing renderers: $e');
    }
  }

  void _updateLocalStream() {
    final localStream = _callController.localStream;
    if (localStream != null && widget.args.isVideo && !_isLocalVideoInitialized) {
      _localRenderer.srcObject = localStream;
      if (mounted) {
        setState(() {
          _isLocalVideoInitialized = true;
        });
      }
    }
  }

  void _updateRemoteStream() {
    final remoteStream = _callController.remoteStream;
    if (remoteStream != null && widget.args.isVideo && !_isRemoteVideoInitialized) {
      _remoteRenderer.srcObject = remoteStream;
      if (mounted) {
        setState(() {
          _isRemoteVideoInitialized = true;
        });
      }
    }
  }

  void _setupCallListeners() {
    // Start timer when call is accepted
    ever(_callController.currentStatus, (status) {
      if (status == CallStatus.accepted && !_callTimer.isRunning) {
        _callTimer.start();
        _startTimerUpdates();
      } else if (status == CallStatus.ended) {
        _callTimer.stop();
        _stopTimerUpdates();
        // Automatically close screen when call ends
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Get.back();
          });
        }
      }
    });

    // Check initial status
    if (_callController.currentStatus.value == CallStatus.accepted) {
      _callTimer.start();
      _startTimerUpdates();
    }
  }

  void _startTimerUpdates() {
    _timerUpdateTimer?.cancel();
    _timerUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _callTimer.isRunning) {
        setState(() {
          _callDurationText = _callTimer.formatted;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _stopTimerUpdates() {
    _timerUpdateTimer?.cancel();
    _timerUpdateTimer = null;
    if (mounted) {
      setState(() {
        _callDurationText = '00:00';
      });
    }
  }

  Future<void> _loadRemoteUserInfo() async {
    try {
      final user = await _userRepository.getUserById(widget.args.remoteUserId);
      if (user != null) {
        setState(() {
          _remoteUserName = user.nomComplet;
        });

        if (user.type.toLowerCase() == 'employee') {
          final employee = await _employeeRepository.getEmployeeByUserId(widget.args.remoteUserId);
          if (employee != null && employee.image != null) {
            setState(() {
              _remoteUserAvatar = employee.image;
            });
          }
        }
      }
    } catch (e) {
      print('[CallScreen] Error loading remote user info: $e');
    }
  }

  void _toggleMute() {
    _callController.toggleMute();
  }

  void _toggleSpeaker() {
    _callController.toggleSpeaker();
  }

  void _toggleCamera() {
    if (!widget.args.isVideo) return;
    
    // Toggle camera on/off
    setState(() {
      _isCameraOn = !_isCameraOn;
    });
    final localStream = _callController.localStream;
    if (localStream != null) {
      localStream.getVideoTracks().forEach((track) {
        track.enabled = _isCameraOn;
      });
    }
  }

  Future<void> _switchCamera() async {
    if (!widget.args.isVideo) return;
    
    await _callController.toggleCamera();
    // Update local renderer when camera switches
    _updateLocalStream();
  }

  void _endCall() {
    _callTimer.stop();
    _callController.endCall(widget.args.callId);
    Get.back();
  }

  @override
  void dispose() {
    _streamCheckTimer?.cancel();
    _timerUpdateTimer?.cancel();
    _callTimer.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent back button - must use End Call button
        _endCall();
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.night,
        body: SafeArea(
          child: Stack(
            children: [
              // Remote Video (full screen for video, or avatar for audio)
              if (widget.args.isVideo && _isRemoteVideoInitialized)
                SizedBox.expand(
                  child: RTCVideoView(
                    _remoteRenderer,
                    mirror: false,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                )
              else
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 80,
                        backgroundColor: AppColors.primaryLight.withOpacity(0.2),
                        backgroundImage: _remoteUserAvatar != null
                            ? NetworkImage(_remoteUserAvatar!)
                            : null,
                        child: _remoteUserAvatar == null
                            ? Text(
                                _remoteUserName?.isNotEmpty == true
                                    ? _remoteUserName![0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.white,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _remoteUserName ?? 'Unknown User',
                        style: AppTextStyles.h2.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Obx(() {
                        // Access observable directly to trigger GetX reactivity
                        final status = _callController.currentStatus.value;
                        String statusText;
                        switch (status) {
                          case CallStatus.ringing:
                            statusText = 'Ringing...';
                            break;
                          case CallStatus.accepted:
                            statusText = 'Connected';
                            break;
                          case CallStatus.ended:
                            statusText = 'Call Ended';
                            break;
                        }
                        return Text(
                          statusText,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.white.withOpacity(0.7),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              
              // Top Bar with Timer and Status
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.black.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _callDurationText,
                        style: AppTextStyles.h4.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Obx(() {
                        // Access observable directly to trigger GetX reactivity
                        final status = _callController.currentStatus.value;
                        String statusText;
                        switch (status) {
                          case CallStatus.ringing:
                            statusText = 'Ringing...';
                            break;
                          case CallStatus.accepted:
                            statusText = 'Connected';
                            break;
                          case CallStatus.ended:
                            statusText = 'Call Ended';
                            break;
                        }
                        return Text(
                          statusText,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.white.withOpacity(0.8),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // Local Video (small overlay for video calls)
              if (widget.args.isVideo && _isLocalVideoInitialized)
                Positioned(
                  top: 60,
                  right: 16,
                  child: GestureDetector(
                    onTap: () {
                      // Optional: Tap to swap local/remote video positions
                    },
                    child: Container(
                      width: 120,
                      height: 160,
                      decoration: BoxDecoration(
                        color: AppColors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: RTCVideoView(
                          _localRenderer,
                          mirror: true,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                      ),
                    ),
                  ),
                ),
              
              // Control Buttons (bottom)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppColors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Mute Button
                      Obx(() => _buildControlButton(
                        icon: _callController.isMuted.value ? Icons.mic_off : Icons.mic,
                        label: _callController.isMuted.value ? 'Unmute' : 'Mute',
                        onPressed: _toggleMute,
                        isActive: !_callController.isMuted.value,
                      )),
                      // Camera Toggle (only for video)
                      if (widget.args.isVideo) ...[
                        _buildControlButton(
                          icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                          label: _isCameraOn ? 'Camera Off' : 'Camera On',
                          onPressed: _toggleCamera,
                          isActive: _isCameraOn,
                        ),
                        // Switch Camera Button (only for video)
                        Obx(() => _buildControlButton(
                          icon: _callController.useBackCamera.value 
                              ? Icons.camera_front 
                              : Icons.camera_rear,
                          label: _callController.useBackCamera.value 
                              ? 'Front Camera' 
                              : 'Back Camera',
                          onPressed: _switchCamera,
                          isActive: true,
                        )),
                      ],
                      // Speaker Button
                      Obx(() => _buildControlButton(
                        icon: _callController.isSpeakerOn.value ? Icons.volume_up : Icons.hearing,
                        label: _callController.isSpeakerOn.value ? 'Speaker Off' : 'Speaker On',
                        onPressed: _toggleSpeaker,
                        isActive: _callController.isSpeakerOn.value,
                      )),
                      // End Call Button
                      _buildControlButton(
                        icon: Icons.call_end,
                        label: 'End',
                        onPressed: _endCall,
                        isActive: false,
                        color: AppColors.error,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isActive,
    Color? color,
  }) {
    final buttonColor = color ?? (isActive ? AppColors.white : AppColors.grey);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: buttonColor.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: buttonColor.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: IconButton(
            icon: Icon(icon, color: buttonColor, size: 24),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}
