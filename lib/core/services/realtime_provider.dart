import 'dart:async';
import 'package:flutter/foundation.dart';

/// Provider abstrait pour les mises à jour en temps réel
/// Permet de basculer entre Firestore streams et WebSocket
abstract class RealtimeProvider {
  Stream<dynamic> get dataStream;
  Stream<bool> get connectionStatusStream;
  bool get isConnected;
  
  void start();
  void stop();
  void dispose();
}

/// Implémentation Firestore (par défaut)
class FirestoreRealtimeProvider implements RealtimeProvider {
  final Stream<dynamic> _dataStream;
  final Stream<bool> _connectionStream;
  final bool _isConnected;
  final VoidCallback _startCallback;
  final VoidCallback _stopCallback;
  final VoidCallback _disposeCallback;

  FirestoreRealtimeProvider({
    required Stream<dynamic> dataStream,
    required Stream<bool> connectionStream,
    required bool isConnected,
    required VoidCallback onStart,
    required VoidCallback onStop,
    required VoidCallback onDispose,
  })  : _dataStream = dataStream,
        _connectionStream = connectionStream,
        _isConnected = isConnected,
        _startCallback = onStart,
        _stopCallback = onStop,
        _disposeCallback = onDispose;

  @override
  Stream<dynamic> get dataStream => _dataStream;

  @override
  Stream<bool> get connectionStatusStream => _connectionStream;

  @override
  bool get isConnected => _isConnected;

  @override
  void start() => _startCallback();

  @override
  void stop() => _stopCallback();

  @override
  void dispose() => _disposeCallback();
}

/// Implémentation WebSocket (pour usage futur)
class WebSocketRealtimeProvider implements RealtimeProvider {
  // TODO: Implémenter quand le backend WebSocket sera disponible
  @override
  Stream<dynamic> get dataStream => throw UnimplementedError('WebSocket not yet implemented');

  @override
  Stream<bool> get connectionStatusStream => throw UnimplementedError('WebSocket not yet implemented');

  @override
  bool get isConnected => throw UnimplementedError('WebSocket not yet implemented');

  @override
  void start() => throw UnimplementedError('WebSocket not yet implemented');

  @override
  void stop() => throw UnimplementedError('WebSocket not yet implemented');

  @override
  void dispose() => throw UnimplementedError('WebSocket not yet implemented');
}

