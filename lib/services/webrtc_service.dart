import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../config/webrtc_config.dart';

/// WebRTC Service for audio-only calls
/// 
/// Handles peer connection creation with TURN/STUN server configuration
/// for reliable connections across NAT/firewalls and mobile networks.
class WebRTCService {
  const WebRTCService();

  /// Get ICE servers configuration (STUN + optional TURN)
  /// 
  /// Uses centralized configuration from WebRTCConfig.
  /// STUN servers are free and sufficient for most cases.
  /// TURN servers are required for NAT/firewall traversal in restrictive networks.
  List<Map<String, dynamic>> _getIceServers() {
    final iceServers = WebRTCConfig.getIceServers();
    
    // Log configuration
    print(WebRTCConfig.getConfigSummary());
    
    if (!WebRTCConfig.hasTurnServers) {
      print('[WebRTCService] Note: No TURN servers configured.');
      print('[WebRTCService] Calls may fail behind restrictive NAT/firewalls.');
      print('[WebRTCService] To configure TURN, update lib/config/webrtc_config.dart');
    }

    return iceServers;
  }

  /// Build RTCPeerConnection with TURN/STUN configuration
  /// 
  /// Configuration includes:
  /// - Multiple STUN servers for redundancy
  /// - Optional TURN servers for NAT/firewall traversal
  /// - Unified-plan SDP semantics (required for modern WebRTC)
  /// - Audio-only constraints
  Future<RTCPeerConnection> buildPeerConnection() async {
    final iceServers = _getIceServers();
    
    final configuration = {
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
      // Optional: Configure ICE transport policy
      // 'iceTransportPolicy': 'all', // 'all' or 'relay' (relay = TURN only)
    };

    // Constraints for audio-only calls
    final constraints = {
      'mandatory': {},
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ],
    };

    print('[WebRTCService] Creating peer connection with ${iceServers.length} ICE servers');
    
    try {
      final peerConnection = await createPeerConnection(configuration, constraints);
      print('[WebRTCService] Peer connection created successfully');
      return peerConnection;
    } catch (e) {
      print('[WebRTCService] Error creating peer connection: $e');
      rethrow;
    }
  }

  /// Create local media stream (audio-only for this task)
  /// 
  /// For audio-only calls:
  /// - audio: true
  /// - video: false
  /// 
  /// No camera permissions required for audio-only calls.
  Future<MediaStream> createLocalStream({required bool withVideo}) async {
    // Audio-only constraints (no video, no camera)
    final mediaConstraints = <String, dynamic>{
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
        // Optional: Specify audio source
        // 'source': 'microphone',
      },
      'video': withVideo
          ? {
              'facingMode': 'user',
              'width': {'ideal': 1280},
              'height': {'ideal': 720},
            }
          : false,
    };

    print('[WebRTCService] Creating local stream: audio=true, video=$withVideo');
    
    try {
      final stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      print('[WebRTCService] Local stream created: ${stream.getAudioTracks().length} audio track(s)');
      if (withVideo) {
        print('[WebRTCService] Local stream: ${stream.getVideoTracks().length} video track(s)');
      }
      return stream;
    } catch (e) {
      print('[WebRTCService] Error creating local stream: $e');
      rethrow;
    }
  }
}


