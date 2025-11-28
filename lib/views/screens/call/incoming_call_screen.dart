/// Incoming Call Screen
/// 
/// Full-screen modal overlay for incoming calls.
/// 
/// Testing:
/// 1. User A starts a call to User B (both apps in foreground)
/// 2. User B should see this screen with caller info
/// 3. Tap Accept -> navigates to CallScreen
/// 4. Tap Decline -> calls endCall and closes modal
/// 
/// Integration:
/// This screen is automatically shown when CallController.listenForIncomingCalls()
/// detects a new ringing call in Firestore.

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/call_controller.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../../utils/call_permissions.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class IncomingCallScreenArguments {
  final String callId;
  final String callerId;
  final bool isVideo;

  const IncomingCallScreenArguments({
    required this.callId,
    required this.callerId,
    required this.isVideo,
  });
}

class IncomingCallScreen extends StatefulWidget {
  final IncomingCallScreenArguments args;

  const IncomingCallScreen({super.key, required this.args});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final CallController _callController = Get.find<CallController>();
  final UserRepository _userRepository = UserRepository();
  final EmployeeRepository _employeeRepository = EmployeeRepository();

  String? _callerName;
  String? _callerAvatar;
  bool _isLoading = true;
  bool _isProcessing = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _callStatusSubscription;

  @override
  void initState() {
    super.initState();
    _loadCallerInfo();
    _listenToCallStatus();
  }

  /// Écouter les changements de statut de l'appel dans Firestore
  void _listenToCallStatus() {
    final callDoc = FirebaseFirestore.instance.collection('calls').doc(widget.args.callId);
    _callStatusSubscription = callDoc.snapshots().listen((doc) {
      if (!doc.exists) {
        // L'appel a été supprimé, fermer l'écran
        if (mounted) {
          Get.back();
        }
        return;
      }

      final data = doc.data();
      final status = data?['status'] as String?;
      
      // Si l'appel est terminé (ended) ou accepté (et qu'on n'est pas en train de traiter), fermer l'écran
      if (status == 'ended') {
        print('[IncomingCallScreen] Call ended, closing screen');
        if (mounted && !_isProcessing) {
          Get.back();
        }
      } else if (status == 'accepted' && !_isProcessing) {
        // L'appel a été accepté (peut-être par une autre action), fermer cet écran
        // Le CallController naviguera vers CallScreen
        print('[IncomingCallScreen] Call accepted, closing incoming screen');
        if (mounted) {
          Get.back();
        }
      }
    });
  }

  Future<void> _loadCallerInfo() async {
    try {
      final user = await _userRepository.getUserById(widget.args.callerId);
      if (user != null) {
        setState(() {
          _callerName = user.nomComplet;
        });

        // Try to get avatar from employee
        if (user.type.toLowerCase() == 'employee') {
          final employee = await _employeeRepository.getEmployeeByUserId(widget.args.callerId);
          if (employee != null && employee.image != null) {
            setState(() {
              _callerAvatar = employee.image;
            });
          }
        }
      }
    } catch (e) {
      print('[IncomingCallScreen] Error loading caller info: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleAccept() async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });

    // Request permissions before accepting
    final hasPermissions = await CallPermissions.requestPermissions(
      video: widget.args.isVideo,
    );

    if (!hasPermissions) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
      // User denied permissions, end the call
      _callController.endCall(widget.args.callId);
      Get.back();
      return;
    }

    // Accept the call (navigation will be handled by CallController)
    await _callController.acceptCall(widget.args.callId);
  }

  void _handleDecline() {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });
    _callController.endCall(widget.args.callId);
    // La navigation sera gérée par le listener de statut ou on ferme manuellement
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        Get.back();
      }
    });
  }

  @override
  void dispose() {
    _callStatusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent back button from dismissing - must use Decline button
        _handleDecline();
        return false;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 60),
              // Caller Avatar
              CircleAvatar(
                radius: 80,
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                backgroundImage: _callerAvatar != null
                    ? NetworkImage(_callerAvatar!)
                    : null,
                child: _callerAvatar == null
                    ? Text(
                        _callerName?.isNotEmpty == true
                            ? _callerName![0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 32),
              // Caller Name
              Text(
                _isLoading
                    ? 'Loading...'
                    : (_callerName ?? 'Unknown User'),
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: 16),
              // "is calling..." text
              Text(
                'is calling...',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              // Call Type
              Text(
                widget.args.isVideo ? 'Video Call' : 'Audio Call',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.white.withOpacity(0.6),
                ),
              ),
              const Spacer(),
              // Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Decline Button (Red)
                    _buildActionButton(
                      icon: Icons.call_end,
                      color: AppColors.error,
                      onPressed: _isProcessing ? null : _handleDecline,
                      label: 'Decline',
                    ),
                    const SizedBox(width: 32),
                    // Accept Button (Green)
                    _buildActionButton(
                      icon: Icons.call,
                      color: AppColors.success,
                      onPressed: _isProcessing ? null : _handleAccept,
                      label: 'Accept',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 16,
                spreadRadius: 4,
              ),
            ],
          ),
          child: IconButton(
            icon: _isProcessing && onPressed != null
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                    ),
                  )
                : Icon(icon, color: AppColors.white, size: 28),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}
