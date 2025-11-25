import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';

import '../models/call_session.dart';
import '../services/webrtc_service.dart';
import '../core/services/local_notification_service.dart';
import 'auth_controller.dart';

class CallController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WebRTCService _webRTCService = const WebRTCService();
  final AuthController _authController = Get.find<AuthController>();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  String? _currentCallId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _callSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _candidatesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _incomingCallsSub;

  final Rx<CallStatus> currentStatus = CallStatus.ringing.obs;
  final RxBool hasActiveCall = false.obs;
  
  // Audio control state
  final RxBool isMuted = false.obs;
  final RxBool isSpeakerOn = false.obs;
  
  // Camera control state
  final RxBool useBackCamera = false.obs;

  // Getters for UI
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  @override
  void onClose() {
    _incomingCallsSub?.cancel();
    _disposeCurrentCall();
    super.onClose();
  }

  Future<void> startCall(
    String calleeId, {
    bool video = false,
  }) async {
    final callerId = _authController.currentUser.value?.id;
    if (callerId == null) {
      print('[CallController] Cannot start call: user not authenticated.');
      return;
    }
    if (hasActiveCall.value) {
      print('[CallController] Already in call $_currentCallId');
      return;
    }

    try {
      // Note: Permissions should be requested before calling this method
      // The UI (CallButton) handles permission requests
      _localStream = await _webRTCService.createLocalStream(
        withVideo: video,
        useBackCamera: useBackCamera.value,
      );
      if (_localStream == null) {
        throw Exception('Failed to create local stream');
      }
      
      // Verify stream has tracks before proceeding
      final tracks = _localStream!.getTracks();
      if (tracks.isEmpty) {
        throw Exception('Local stream has no tracks');
      }
      print('[CallController] Local stream created with ${tracks.length} track(s)');
      
      _peerConnection = await _webRTCService.buildPeerConnection();
      if (_peerConnection == null) {
        throw Exception('Failed to create peer connection');
      }
      
      _setupPeerConnectionListeners();
      await _addLocalTracks();

      final callDoc = _firestore.collection('calls').doc();
      _currentCallId = callDoc.id;
      hasActiveCall.value = true;
      currentStatus.value = CallStatus.ringing;

      _listenToCallDoc(callDoc.id);
      _listenToRemoteCandidates(callDoc.id);

      // Get caller name for FCM notification
      final callerName = _authController.currentUser.value?.nomComplet ?? 'Unknown';

      await callDoc.set({
        'callerId': callerId,
        'calleeId': calleeId,
        'callerName': callerName, // Required for FCM notification
        'type': video ? 'video' : 'audio',
        'status': 'ringing',
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });

      await _createOffer(callDoc);
      print('[CallController] Call started: ${callDoc.id}');
      
      // For audio calls, optionally enable speakerphone by default
      if (!video) {
        try {
          Helper.setSpeakerphoneOn(true);
          isSpeakerOn.value = true;
          print('[CallController] Speakerphone enabled for audio call');
        } catch (e) {
          print('[CallController] Error enabling speakerphone: $e');
        }
      }
      
      // Navigate to call screen
      Get.toNamed('/call', arguments: {
        'callId': callDoc.id,
        'remoteUserId': calleeId,
        'isVideo': video,
      });
    } catch (e) {
      print('[CallController] startCall error: $e');
      await _disposeCurrentCall();
      rethrow; // Re-throw so UI can handle the error
    }
  }

  Future<void> acceptCall(String callId) async {
    // Cancel incoming call notification
    try {
      final localNotificationService = LocalNotificationService();
      await localNotificationService.cancelNotification(callId.hashCode);
    } catch (e) {
      print('[CallController] Error canceling notification: $e');
    }
    final userId = _authController.currentUser.value?.id;
    if (userId == null) return;

    final doc = await _firestore.collection('calls').doc(callId).get();
    if (!doc.exists) {
      print('[CallController] Call $callId no longer exists.');
      return;
    }

    final call = CallSession.fromDoc(doc);
    if (call.calleeId != userId) {
      print('[CallController] Not the callee for call $callId.');
      return;
    }
    if (call.status == CallStatus.ended) {
      print('[CallController] Call already ended.');
      return;
    }

    final withVideo = call.type == CallType.video;
    _currentCallId = callId;
    hasActiveCall.value = true;
    currentStatus.value = CallStatus.accepted;

    try {
      // Create local stream first and verify it's valid
      _localStream = await _webRTCService.createLocalStream(
        withVideo: withVideo,
        useBackCamera: useBackCamera.value,
      );
      if (_localStream == null) {
        throw Exception('Failed to create local stream');
      }
      
      // Verify stream has tracks before proceeding
      final tracks = _localStream!.getTracks();
      if (tracks.isEmpty) {
        throw Exception('Local stream has no tracks');
      }
      print('[CallController] Local stream created with ${tracks.length} track(s)');
      
      // Create peer connection
      _peerConnection = await _webRTCService.buildPeerConnection();
      if (_peerConnection == null) {
        throw Exception('Failed to create peer connection');
      }
      
      // Setup listeners before adding tracks
      _setupPeerConnectionListeners();
      
      // Add local tracks to peer connection
      await _addLocalTracks();

      _listenToCallDoc(callId);
      _listenToRemoteCandidates(callId);

      if (call.sdpOffer != null) {
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(
            call.sdpOffer!['sdp'],
            call.sdpOffer!['type'] ?? 'offer',
          ),
        );
      }
      await _createAnswer(doc.reference);
      await doc.reference.update({
        'status': 'accepted',
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
      print('[CallController] Accepted call $callId');
      
      // For audio calls, optionally enable speakerphone by default
      if (!withVideo) {
        try {
          Helper.setSpeakerphoneOn(true);
          isSpeakerOn.value = true;
          print('[CallController] Speakerphone enabled for audio call');
        } catch (e) {
          print('[CallController] Error enabling speakerphone: $e');
        }
      }
      
      // Navigate to call screen (with delay to ensure Overlay is ready)
      Future.delayed(const Duration(milliseconds: 100), () {
        try {
          Get.offNamed('/call', arguments: {
            'callId': callId,
            'remoteUserId': call.callerId,
            'isVideo': withVideo,
          });
        } catch (e) {
          print('[CallController] Error navigating to call screen: $e');
          // Retry after longer delay
          Future.delayed(const Duration(milliseconds: 500), () {
            try {
              Get.offNamed('/call', arguments: {
                'callId': callId,
                'remoteUserId': call.callerId,
                'isVideo': withVideo,
              });
            } catch (e2) {
              print('[CallController] Error navigating to call screen after retry: $e2');
            }
          });
        }
      });
    } catch (e) {
      print('[CallController] acceptCall error: $e');
      await _disposeCurrentCall();
    }
  }

  Future<void> endCall(String callId) async {
    // Cancel incoming call notification
    try {
      final localNotificationService = LocalNotificationService();
      await localNotificationService.cancelNotification(callId.hashCode);
    } catch (e) {
      print('[CallController] Error canceling notification: $e');
    }
    
    if (_currentCallId != callId) {
      print('[CallController] Call ID mismatch: current=$_currentCallId, requested=$callId');
      return;
    }

    try {
      // Update Firestore status
      await _firestore.collection('calls').doc(callId).update({
        'status': 'ended',
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Cleanup signaling subcollections (candidates)
      await _cleanupCallSignaling(callId);

      // Dispose peer connection and streams
      await _disposeCurrentCall();
      
      // Reset audio control state
      isMuted.value = false;
      isSpeakerOn.value = false;
      
      print('[CallController] Call $callId ended.');
      
      // Navigation back will be handled by the screen
    } catch (e) {
      print('[CallController] Error ending call: $e');
      // Still try to cleanup even if Firestore update fails
      await _disposeCurrentCall();
    }
  }

  /// Cleanup signaling subcollections (ICE candidates)
  Future<void> _cleanupCallSignaling(String callId) async {
    try {
      final candidatesRef = _firestore
          .collection('calls')
          .doc(callId)
          .collection('candidates');
      
      final candidatesSnapshot = await candidatesRef.get();
      
      // Delete all candidate documents in batch
      final batch = _firestore.batch();
      for (final doc in candidatesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      if (candidatesSnapshot.docs.isNotEmpty) {
        await batch.commit();
        print('[CallController] Cleaned up ${candidatesSnapshot.docs.length} candidate documents');
      }
    } catch (e) {
      print('[CallController] Error cleaning up signaling: $e');
      // Non-critical error, continue
    }
  }

  /// Reject an incoming call (same as endCall but semantically clearer)
  Future<void> rejectCall(String callId) async {
    await endCall(callId);
  }

  /// Handle incoming call from FCM notification (audio-only)
  /// This is called when a push notification is received for an incoming audio call
  void handleIncomingCallFromFCM({
    required String callId,
    required String callerId,
    bool isVideo = false, // Should always be false for FCM calls
  }) {
    if (hasActiveCall.value) {
      print('[CallController] Already in call, ignoring FCM call ${callId}');
      return;
    }

    print('[CallController] Handling incoming call from FCM: ${callId}');
    
    // Navigate to incoming call screen with retry logic to ensure Overlay is ready
    _navigateToIncomingCallScreen(
      callId: callId,
      callerId: callerId,
      isVideo: isVideo,
    );
  }

  /// Navigate to incoming call screen with retry logic
  void _navigateToIncomingCallScreen({
    required String callId,
    required String callerId,
    required bool isVideo,
    int retryCount = 0,
  }) {
    try {
      // Check if GetX Navigator is ready by checking if we can access the navigator
      final navigator = Get.key.currentState;
      if (navigator == null) {
        if (retryCount < 10) {
          print('[CallController] Navigator not ready yet, retrying... (attempt ${retryCount + 1})');
          Future.delayed(Duration(milliseconds: 100 * (retryCount + 1)), () {
            _navigateToIncomingCallScreen(
              callId: callId,
              callerId: callerId,
              isVideo: isVideo,
              retryCount: retryCount + 1,
            );
          });
          return;
        } else {
          print('[CallController] Navigator not available after retries, cannot navigate to incoming call');
          return;
        }
      }

      // Navigate to incoming call screen
      try {
        Get.toNamed('/incoming-call', arguments: {
          'callId': callId,
          'callerId': callerId,
          'isVideo': isVideo,
        });
      } catch (navError) {
        // If error is about Overlay, retry
        if (navError.toString().contains('Overlay') && retryCount < 10) {
          print('[CallController] Overlay not ready, retrying navigation... (attempt ${retryCount + 1})');
          Future.delayed(Duration(milliseconds: 100 * (retryCount + 1)), () {
            _navigateToIncomingCallScreen(
              callId: callId,
              callerId: callerId,
              isVideo: isVideo,
              retryCount: retryCount + 1,
            );
          });
          return;
        } else {
          rethrow; // Re-throw if not Overlay error or max retries reached
        }
      }
    } catch (e) {
      print('[CallController] Error navigating to incoming call screen: $e');
      // Final retry if not already handled
      if (retryCount < 10 && e.toString().contains('Overlay')) {
        Future.delayed(Duration(milliseconds: 200 * (retryCount + 1)), () {
          _navigateToIncomingCallScreen(
            callId: callId,
            callerId: callerId,
            isVideo: isVideo,
            retryCount: retryCount + 1,
          );
        });
      }
    }
  }

  void listenForIncomingCalls() {
    final userId = _authController.currentUser.value?.id;
    if (userId == null) return;

    _incomingCallsSub?.cancel();
    _incomingCallsSub = _firestore
        .collection('calls')
        .where('calleeId', isEqualTo: userId)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((snapshot) async {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final callId = doc.id;
        final callerId = data['callerId'] as String?;
        final isVideo = (data['type'] as String?) == 'video';
        final callerName = data['callerName'] as String? ?? 'Someone';
        
        if (callerId != null && !hasActiveCall.value) {
          print('[CallController] Incoming call from $callerId (callId: $callId)');
          
          // Show notification in status bar (even in foreground)
          try {
            final localNotificationService = LocalNotificationService();
            await localNotificationService.showIncomingCallNotification(
              id: callId.hashCode,
              title: 'Incoming ${isVideo ? 'Video' : 'Audio'} Call',
              body: '${isVideo ? 'Video' : 'Audio'} call from $callerName',
              callId: callId,
              callerId: callerId,
              isVideo: isVideo,
              callerName: callerName,
            );
            print('[CallController] ✅ Notification shown for incoming call: $callId');
          } catch (e) {
            print('[CallController] ❌ Error showing notification: $e');
          }
          
          // Navigate to incoming call screen with retry logic
          _navigateToIncomingCallScreen(
            callId: callId,
            callerId: callerId,
            isVideo: isVideo,
          );
        }
      }
    });
  }

  void _setupPeerConnectionListeners() {
    // Handle remote media tracks (audio for audio-only calls)
    _peerConnection?.onTrack = (event) {
      final track = event.track;
      print('[CallController] Remote track received: ${track.kind}');
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        print('[CallController] Remote stream set from event: ${_remoteStream?.id}');
      } else {
        // Create a new stream if needed
        print('[CallController] Warning: No stream in track event, creating new stream');
        // Don't try to add track to null stream - the track is already associated with the peer connection
        // The stream will be available through the peer connection's transceivers
        return;
      }
      // Note: Don't manually add track to stream - it's already associated via the peer connection
      // Manually adding can cause "stream is null" errors
    };

    // Monitor connection state changes
    _peerConnection?.onConnectionState = (state) {
      print('[CallController] Connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        currentStatus.value = CallStatus.accepted;
        print('[CallController] Peer connection established successfully');
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
                 state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
                 state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        print('[CallController] Peer connection failed or closed: $state');
        if (_currentCallId != null) {
          endCall(_currentCallId!);
        }
      }
    };

    // Monitor ICE connection state (for debugging NAT/firewall issues)
    _peerConnection?.onIceConnectionState = (state) {
      print('[CallController] ICE connection state: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        print('[CallController] ICE connection failed. This may indicate NAT/firewall issues.');
        print('[CallController] Consider configuring TURN servers for better reliability.');
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
                 state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        print('[CallController] ICE connection established successfully');
      }
    };

    // Monitor ICE gathering state
    _peerConnection?.onIceGatheringState = (state) {
      print('[CallController] ICE gathering state: $state');
    };

    // Monitor ICE candidates (for debugging)
    // Note: This is a duplicate handler - ICE candidates are already handled by _handleLocalCandidate
    // in _createOffer and _createAnswer. This is kept for additional logging if needed.
    // _peerConnection?.onIceCandidate is already set in _createOffer/_createAnswer
  }

  Future<void> _createOffer(DocumentReference<Map<String, dynamic>> callDoc) async {
    _peerConnection!.onIceCandidate =
        (candidate) => _handleLocalCandidate(callDoc.id, candidate);
    _peerConnection!.onConnectionState =
        (state) => print('[CallController] Connection state: $state');

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    await callDoc.update({
      'sdpOffer': jsonDecode(jsonEncode(offer.toMap())),
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    });
    print('[CallController] Offer published.');
  }

  Future<void> _createAnswer(DocumentReference<Map<String, dynamic>> callDoc) async {
    _peerConnection!.onIceCandidate =
        (candidate) => _handleLocalCandidate(callDoc.id, candidate);
    _peerConnection!.onConnectionState =
        (state) => print('[CallController] Connection state: $state');

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    await callDoc.update({
      'sdpAnswer': jsonDecode(jsonEncode(answer.toMap())),
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    });
    print('[CallController] Answer published.');
  }

  void _listenToCallDoc(String callId) {
    _callSub?.cancel();
    _callSub =
        _firestore.collection('calls').doc(callId).snapshots().listen((doc) async {
      if (!doc.exists) {
        print('[CallController] Call doc deleted.');
        await _disposeCurrentCall();
        // Navigate back if screen is still open
        try {
          if (Get.isDialogOpen == false) {
            Get.back();
          }
        } catch (e) {
          print('[CallController] Error navigating back: $e');
        }
        return;
      }
      final data = doc.data()!;
      final status = data['status'] as String?;
      
      // Update local status based on Firestore status
      if (status != null) {
        CallStatus? newStatus;
        switch (status.toLowerCase()) {
          case 'ringing':
            newStatus = CallStatus.ringing;
            break;
          case 'accepted':
            newStatus = CallStatus.accepted;
            break;
          case 'ended':
            newStatus = CallStatus.ended;
            break;
        }
        
        if (newStatus != null) {
          // Always update status to keep in sync with Firestore
          if (currentStatus.value != newStatus) {
            print('[CallController] Status changed from ${currentStatus.value} to $newStatus (Firestore: $status)');
            currentStatus.value = newStatus;
          }
        }
      }
      
      if (status == 'ended') {
        print('[CallController] Call remote ended.');
        await _disposeCurrentCall();
        // Navigate back if screen is still open
        // Use Get.until to check if we're on the call route
        try {
          if (Get.isDialogOpen == false) {
            Get.back();
          }
        } catch (e) {
          print('[CallController] Error navigating back: $e');
        }
        return;
      }
      await _onRemoteSDPUpdated(data);
    });
  }

  Future<void> _onRemoteSDPUpdated(Map<String, dynamic> data) async {
    if (_peerConnection == null) return;
    if (data['sdpAnswer'] != null) {
      final currentRemote = await _peerConnection!.getRemoteDescription();
      if (currentRemote == null) {
        final answer = RTCSessionDescription(
          data['sdpAnswer']['sdp'],
          data['sdpAnswer']['type'] ?? 'answer',
        );
        await _peerConnection!.setRemoteDescription(answer);
        print('[CallController] Remote SDP (answer) set.');
      }
    }
  }

  void _listenToRemoteCandidates(String callId) {
    _candidatesSub?.cancel();
    _candidatesSub = _firestore
        .collection('calls')
        .doc(callId)
        .collection('candidates')
        .where('senderId', isNotEqualTo: _authController.currentUser.value?.id)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            _onRemoteCandidateAdded(data);
          }
        }
      }
    });
  }

  Future<void> _onRemoteCandidateAdded(Map<String, dynamic> data) async {
    if (_peerConnection == null) return;
    final candidate = RTCIceCandidate(
      data['candidate'],
      data['sdpMid'],
      data['sdpMLineIndex'],
    );
    await _peerConnection!.addCandidate(candidate);
    print('[CallController] Remote ICE candidate applied.');
  }

  Future<void> _handleLocalCandidate(String callId, RTCIceCandidate candidate) async {
    final candidateString = candidate.candidate;
    if (candidateString == null || candidateString.isEmpty) {
      print('[CallController] Skipping empty ICE candidate');
      return;
    }

    try {
      await _firestore.collection('calls').doc(callId).collection('candidates').add({
        'senderId': _authController.currentUser.value?.id,
        'candidate': candidateString,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'createdAt': FieldValue.serverTimestamp(),
      });
      final preview = candidateString.length > 50 
          ? candidateString.substring(0, 50) 
          : candidateString;
      print('[CallController] Local ICE candidate published: $preview...');
    } catch (e) {
      print('[CallController] Error publishing ICE candidate: $e');
      // Continue - candidate publishing failures are non-critical
    }
  }

  Future<void> _addLocalTracks() async {
    if (_localStream == null || _peerConnection == null) {
      print('[CallController] Cannot add local tracks: stream or peer connection is null');
      return;
    }
    
    // Verify stream is valid and has tracks
    if (_localStream!.getTracks().isEmpty) {
      print('[CallController] Warning: Local stream has no tracks');
      return;
    }
    
    try {
      for (var track in _localStream!.getTracks()) {
        // Verify track is not null and has a valid kind
        if (track.kind == null || track.kind!.isEmpty) {
          print('[CallController] Warning: Track has invalid kind, skipping');
          continue;
        }
        await _peerConnection!.addTrack(track, _localStream!);
        print('[CallController] Added ${track.kind} track to peer connection');
      }
    } catch (e) {
      print('[CallController] Error adding local tracks: $e');
      rethrow;
    }
  }

  /// Toggle mute/unmute microphone
  void toggleMute() {
    if (_localStream == null) {
      print('[CallController] Cannot toggle mute: no local stream');
      return;
    }

    isMuted.value = !isMuted.value;
    
    // Get audio tracks and toggle enabled state
    final audioTracks = _localStream!.getAudioTracks();
    for (var track in audioTracks) {
      track.enabled = !isMuted.value;
    }
  }

  /// Toggle between front and back camera (for video calls only)
  Future<void> toggleCamera() async {
    if (_localStream == null || _peerConnection == null) {
      print('[CallController] Cannot toggle camera: no local stream or peer connection');
      return;
    }

    // Get current video tracks
    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isEmpty) {
      print('[CallController] No video tracks to toggle');
      return;
    }

    try {
      // Toggle camera state
      useBackCamera.value = !useBackCamera.value;
      
      // Get audio tracks from current stream to preserve them
      final audioTracks = _localStream!.getAudioTracks();
      
      // Stop old video tracks
      final tracksToStop = List<MediaStreamTrack>.from(videoTracks);
      for (var track in tracksToStop) {
        try {
          await track.stop();
        } catch (e) {
          print('[CallController] Warning: Error stopping old track: $e');
        }
      }
      
      // Create new stream with the other camera
      final newStream = await _webRTCService.createLocalStream(
        withVideo: true,
        useBackCamera: useBackCamera.value,
      );

      // Get new video tracks
      final newVideoTracks = newStream.getVideoTracks();
      if (newVideoTracks.isEmpty) {
        throw Exception('Failed to get video track from new stream');
      }

      // Get senders from peer connection
      final senders = await _peerConnection!.getSenders();
      final videoSender = senders.firstWhere(
        (sender) => sender.track?.kind == 'video',
        orElse: () => throw Exception('No video sender found'),
      );

      // Replace the track in the peer connection
      await videoSender.replaceTrack(newVideoTracks[0]);
      
      // Dispose old stream
      try {
        await _localStream!.dispose();
      } catch (e) {
        print('[CallController] Warning: Error disposing old stream: $e');
      }
      
      // Create new local stream with audio + new video
      _localStream = newStream;
      
      // If we had audio tracks, make sure they're in the new stream
      // (the new stream should already have audio, but verify)
      final newAudioTracks = newStream.getAudioTracks();
      if (newAudioTracks.isEmpty && audioTracks.isNotEmpty) {
        // This shouldn't happen, but just in case
        print('[CallController] Warning: New stream has no audio tracks');
      }

      print('[CallController] Camera switched to ${useBackCamera.value ? "back" : "front"}');
    } catch (e) {
      print('[CallController] Error toggling camera: $e');
      // Revert state on error
      useBackCamera.value = !useBackCamera.value;
      rethrow;
    }
  }

  /// Toggle speakerphone (earpiece <-> loudspeaker)
  void toggleSpeaker() {
    isSpeakerOn.value = !isSpeakerOn.value;
    
    try {
      // Use flutter_webrtc Helper to control speakerphone
      Helper.setSpeakerphoneOn(isSpeakerOn.value);
      print('[CallController] Speakerphone ${isSpeakerOn.value ? "on" : "off"}');
    } catch (e) {
      print('[CallController] Error toggling speaker: $e');
      // Revert state if operation failed
      isSpeakerOn.value = !isSpeakerOn.value;
    }
  }

  Future<void> _disposeCurrentCall() async {
    _callSub?.cancel();
    _candidatesSub?.cancel();
    _callSub = null;
    _candidatesSub = null;

    // Reset speakerphone to default (earpiece)
    try {
      Helper.setSpeakerphoneOn(false);
    } catch (e) {
      print('[CallController] Error resetting speaker: $e');
    }

    final localTracks = _localStream?.getTracks() ?? [];
    for (var track in localTracks) {
      track.stop();
    }
    await _localStream?.dispose();
    _localStream = null;

    final remoteTracks = _remoteStream?.getTracks() ?? [];
    for (var track in remoteTracks) {
      track.stop();
    }
    await _remoteStream?.dispose();
    _remoteStream = null;

    await _peerConnection?.close();
    _peerConnection = null;

    _currentCallId = null;
    hasActiveCall.value = false;
    currentStatus.value = CallStatus.ended;
    print('[CallController] Cleanup complete.');
  }
}


