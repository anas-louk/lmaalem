import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Helper centralisé pour afficher des snackbars sans erreurs d'overlay
class SnackbarHelper {
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  static const Duration _defaultDelay = Duration(milliseconds: 50);

  /// Affiche un snackbar de manière sécurisée via le ScaffoldMessenger global
  static void showSnackbar({
    required String title,
    required String message,
    SnackPosition position = SnackPosition.BOTTOM,
    Duration duration = const Duration(seconds: 3),
    Color? backgroundColor,
    Color? colorText,
    SnackBarAction? action,
  }) {
    void _attemptShow(int attempt) {
      final messenger = scaffoldMessengerKey.currentState;
      if (messenger == null) {
        if (attempt > 10) {
          debugPrint('[SnackbarHelper] Impossible d\'afficher le snackbar: $title - $message');
          return;
        }

        Future.delayed(_defaultDelay, () => _attemptShow(attempt + 1));
        return;
      }

      final bool isTop = position == SnackPosition.TOP;
      final EdgeInsets margin = isTop
          ? const EdgeInsets.only(left: 16, right: 16, top: 80)
          : const EdgeInsets.only(left: 16, right: 16, bottom: 24);

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          duration: duration,
          behavior: SnackBarBehavior.floating,
          margin: margin,
          backgroundColor: backgroundColor ?? Colors.black87,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: action,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colorText ?? Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: TextStyle(
                  color: colorText ?? Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Future.microtask(() => _attemptShow(0));
  }

  /// Affiche un snackbar de succès
  static void showSuccess(String message, {String? title}) {
    showSnackbar(
      title: title ?? 'success'.tr,
      message: message,
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  }

  /// Affiche un snackbar d'erreur
  static void showError(String message, {String? title}) {
    showSnackbar(
      title: title ?? 'error'.tr,
      message: message,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }

  /// Affiche un snackbar d'information
  static void showInfo(String message, {String? title}) {
    showSnackbar(
      title: title ?? 'info'.tr,
      message: message,
      backgroundColor: Colors.blue,
      colorText: Colors.white,
    );
  }

  /// Affiche un snackbar d'avertissement
  static void showWarning(String message, {String? title}) {
    showSnackbar(
      title: title ?? 'warning'.tr,
      message: message,
      backgroundColor: Colors.orange,
      colorText: Colors.white,
    );
  }
}

