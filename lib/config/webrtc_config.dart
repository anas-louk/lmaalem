/// WebRTC Configuration
/// 
/// Centralized configuration for TURN/STUN servers.
/// 
/// For production, update TURN server credentials here.
class WebRTCConfig {
  WebRTCConfig._();

  /// STUN servers (free, for NAT discovery)
  /// 
  /// These are public Google STUN servers, sufficient for most use cases.
  static const List<String> stunServers = [
    'stun:stun.l.google.com:19302',
    'stun:stun1.l.google.com:19302',
    'stun:stun2.l.google.com:19302',
  ];

  /// TURN servers (for NAT/firewall traversal)
  /// 
  /// Required for reliable connections behind restrictive NAT/firewalls.
  /// 
  /// For production, replace with your own TURN server credentials.
  /// 
  /// TURN Server Providers:
  /// - Twilio: https://www.twilio.com/stun-turn
  /// - Metered TURN: https://www.metered.ca/tools/openrelay/
  /// - Self-hosted coturn: https://github.com/coturn/coturn
  /// 
  /// Example configuration:
  /// ```dart
  /// static const List<Map<String, String>> turnServers = [
  ///   {
  ///     'urls': 'turn:turn.example.com:3478',
  ///     'username': 'your-username',
  ///     'credential': 'your-password',
  ///   },
  /// ];
  /// ```
  static const List<Map<String, String>> turnServers = [
    // TODO: Add your TURN server credentials here
    // For testing, STUN servers are usually sufficient
  ];

  /// Get all ICE servers (STUN + TURN)
  static List<Map<String, dynamic>> getIceServers() {
    final iceServers = <Map<String, dynamic>>[];

    // Add STUN servers
    for (final stunUrl in stunServers) {
      iceServers.add({'urls': stunUrl});
    }

    // Add TURN servers
    for (final turnServer in turnServers) {
      iceServers.add({
        'urls': turnServer['urls'],
        'username': turnServer['username'],
        'credential': turnServer['credential'],
      });
    }

    return iceServers;
  }

  /// Check if TURN servers are configured
  static bool get hasTurnServers => turnServers.isNotEmpty;

  /// Get configuration summary for logging
  static String getConfigSummary() {
    final summary = StringBuffer();
    summary.writeln('WebRTC Configuration:');
    summary.writeln('  STUN servers: ${stunServers.length}');
    summary.writeln('  TURN servers: ${turnServers.length}');
    if (!hasTurnServers) {
      summary.writeln('  Warning: No TURN servers configured. Calls may fail behind restrictive NAT/firewalls.');
    }
    return summary.toString();
  }
}

