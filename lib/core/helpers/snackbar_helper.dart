import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

/// Helper centralisé pour afficher des snackbars modernes avec style InDrive
class SnackbarHelper {
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  static const Duration _defaultDelay = Duration(milliseconds: 50);

  /// Affiche un snackbar moderne avec style personnalisé
  static void showSnackbar({
    required String title,
    required String message,
    SnackPosition position = SnackPosition.BOTTOM,
    Duration duration = const Duration(seconds: 4),
    Color? backgroundColor,
    Color? colorText,
    IconData? icon,
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
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          content: Container(
            decoration: BoxDecoration(
              color: backgroundColor ?? AppColors.nightSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (backgroundColor ?? AppColors.nightSurface).withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: (backgroundColor ?? AppColors.primary).withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icône avec fond circulaire
                if (icon != null)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (colorText ?? Colors.white).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: colorText ?? Colors.white,
                      size: 20,
                    ),
                  ),
                if (icon != null) const SizedBox(width: 12),
                // Contenu texte
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: colorText ?? Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: (colorText ?? Colors.white).withOpacity(0.9),
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Action si fournie
                if (action != null) ...[
                  const SizedBox(width: 8),
                  action,
                ],
              ],
            ),
          ),
        ),
      );
    }

    Future.microtask(() => _attemptShow(0));
  }

  /// Affiche un snackbar de succès avec style moderne
  static void showSuccess(String message, {String? title}) {
    showSnackbar(
      title: title ?? 'success'.tr,
      message: message,
      backgroundColor: AppColors.success.withOpacity(0.15),
      colorText: AppColors.success,
      icon: Icons.check_circle_rounded,
    );
  }

  /// Affiche un snackbar d'erreur avec style moderne
  static void showError(String message, {String? title}) {
    showSnackbar(
      title: title ?? 'error'.tr,
      message: message,
      backgroundColor: AppColors.error.withOpacity(0.15),
      colorText: AppColors.error,
      icon: Icons.error_rounded,
    );
  }

  /// Affiche un snackbar d'information avec style moderne
  static void showInfo(String message, {String? title}) {
    showSnackbar(
      title: title ?? 'info'.tr,
      message: message,
      backgroundColor: AppColors.info.withOpacity(0.15),
      colorText: AppColors.info,
      icon: Icons.info_rounded,
    );
  }

  /// Affiche un snackbar d'avertissement avec style moderne
  static void showWarning(String message, {String? title}) {
    showSnackbar(
      title: title ?? 'warning'.tr,
      message: message,
      backgroundColor: AppColors.warning.withOpacity(0.15),
      colorText: AppColors.warning,
      icon: Icons.warning_rounded,
    );
  }
}

