import 'package:flutter/foundation.dart';

/// Utility class for logging errors and debug information
class Logger {
  /// Log an error with context
  static void logError(String context, dynamic error, [StackTrace? stackTrace]) {
    debugPrint('❌ [$context] Error: $error');
    if (stackTrace != null) {
      debugPrint('❌ [$context] StackTrace: $stackTrace');
    }
  }

  /// Log a warning
  static void logWarning(String context, String message) {
    debugPrint('⚠️ [$context] Warning: $message');
  }

  /// Log info
  static void logInfo(String context, String message) {
    debugPrint('ℹ️ [$context] Info: $message');
  }

  /// Log success
  static void logSuccess(String context, String message) {
    debugPrint('✅ [$context] Success: $message');
  }
}

