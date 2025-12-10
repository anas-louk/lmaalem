/// Battery Optimization Utility
/// 
/// Handles battery optimization settings to ensure background notifications work properly.
/// 
/// Usage:
/// ```dart
/// final isIgnored = await BatteryOptimization.isIgnoringBatteryOptimizations();
/// if (!isIgnored) {
///   await BatteryOptimization.requestIgnoreBatteryOptimizations();
/// }
/// ```

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/helpers/snackbar_helper.dart';
import '../core/constants/app_colors.dart';
import '../components/indrive_dialog_template.dart';

class BatteryOptimization {
  /// Check if battery optimization is disabled for this app
  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('[BatteryOptimization] Error checking status: $e');
      // On some devices, this permission might not be available
      // Return true to avoid blocking the app
      return true;
    }
  }

  /// Request to disable battery optimization for this app
  /// 
  /// Shows a dialog explaining why this is needed, then requests the permission.
  /// Returns true if granted, false otherwise.
  static Future<bool> requestIgnoreBatteryOptimizations({
    bool showDialog = true,
  }) async {
    try {
      // First check if already granted
      final isIgnored = await isIgnoringBatteryOptimizations();
      if (isIgnored) {
        debugPrint('[BatteryOptimization] Battery optimization already disabled');
        return true;
      }

      // Check if the permission is available on this device
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (status.isPermanentlyDenied) {
        debugPrint('[BatteryOptimization] Battery optimization permission permanently denied');
        if (showDialog) {
          await _showPermanentlyDeniedDialog();
        }
        return false;
      }

      // Show explanatory dialog if requested
      bool shouldRequest = true;
      if (showDialog) {
        shouldRequest = await _showBatteryOptimizationDialog();
        if (!shouldRequest) {
          debugPrint('[BatteryOptimization] User cancelled battery optimization request or opened settings');
          // If user opened settings, check status after a delay to see if they changed it
          // This will be handled by the app lifecycle listener
          return false;
        }
      }

      // Request the permission only if user didn't open settings directly
      final result = await Permission.ignoreBatteryOptimizations.request();
      
      if (result.isGranted) {
        debugPrint('[BatteryOptimization] ✅ Battery optimization disabled successfully');
        if (showDialog) {
          SnackbarHelper.showSnackbar(
            title: 'Optimisation désactivée',
            message: 'Les notifications en arrière-plan fonctionneront maintenant correctement.',
            backgroundColor: AppColors.success.withOpacity(0.9),
            colorText: AppColors.white,
            duration: const Duration(seconds: 3),
          );
        }
        return true;
      } else if (result.isPermanentlyDenied) {
        debugPrint('[BatteryOptimization] Permission permanently denied');
        if (showDialog) {
          await _showPermanentlyDeniedDialog();
        }
        return false;
      } else {
        // Permission denied but not permanently - open settings directly
        debugPrint('[BatteryOptimization] Permission denied: $result - opening settings');
        if (showDialog) {
          await _showPermanentlyDeniedDialog();
        }
        return false;
      }
    } catch (e) {
      debugPrint('[BatteryOptimization] Error requesting permission: $e');
      // On some devices, this permission might not be available
      // Return true to avoid blocking the app
      return true;
    }
  }

  /// Show dialog explaining why battery optimization needs to be disabled
  static Future<bool> _showBatteryOptimizationDialog() async {
    final result = await Get.dialog<bool>(
      InDriveDialogTemplate(
        title: 'Optimisation de la batterie',
        message: 'Pour recevoir des notifications en arrière-plan (nouvelles demandes, appels, etc.), veuillez désactiver l\'optimisation de la batterie pour cette application.\n\n'
            'Cela permettra à l\'application de fonctionner en arrière-plan et de vous notifier en temps réel.',
        primaryLabel: 'Désactiver l\'optimisation',
        onPrimary: () async {
          Get.back(result: false); // Return false to skip request() call
          // Mark that we're opening settings so we can check on return
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('battery_settings_opened', true);
          // Open settings directly - user will configure manually
          openAppSettings();
        },
        secondaryLabel: 'Plus tard',
        onSecondary: () => Get.back(result: false),
      ),
      barrierDismissible: false,
    );

    return result ?? false;
  }

  /// Show dialog when permission is permanently denied
  static Future<void> _showPermanentlyDeniedDialog() async {
    await Get.dialog(
      InDriveDialogTemplate(
        title: 'Paramètres requis',
        message: 'L\'optimisation de la batterie a été refusée. Pour recevoir des notifications en arrière-plan, veuillez :\n\n'
            '1. Aller dans Paramètres → Applications → lmaalem\n'
            '2. Appuyer sur Batterie\n'
            '3. Sélectionner "Ne pas optimiser"',
        primaryLabel: 'Ouvrir les paramètres',
        onPrimary: () async {
          Get.back();
          // Mark that we're opening settings so we can check on return
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('battery_settings_opened', true);
          openAppSettings();
        },
        secondaryLabel: 'Annuler',
        onSecondary: () => Get.back(),
      ),
      barrierDismissible: false,
    );
  }

  /// Check battery optimization status when app resumes (call this from app lifecycle)
  static Future<void> checkStatusOnResume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsOpened = prefs.getBool('battery_settings_opened') ?? false;
      
      if (settingsOpened) {
        // Clear the flag
        await prefs.setBool('battery_settings_opened', false);
        
        // Check if optimization is now disabled
        final isIgnored = await isIgnoringBatteryOptimizations();
        if (isIgnored) {
          SnackbarHelper.showSnackbar(
            title: 'Optimisation désactivée',
            message: 'Les notifications en arrière-plan fonctionneront maintenant correctement.',
            backgroundColor: AppColors.success.withOpacity(0.9),
            colorText: AppColors.white,
            duration: const Duration(seconds: 3),
          );
        }
      }
    } catch (e) {
      debugPrint('[BatteryOptimization] Error checking status on resume: $e');
    }
  }

  /// Open app settings where user can manually disable battery optimization
  static Future<void> openBatterySettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      debugPrint('[BatteryOptimization] Error opening app settings: $e');
    }
  }
}

