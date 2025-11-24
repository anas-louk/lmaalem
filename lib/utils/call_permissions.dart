/// Call Permissions Utility
/// 
/// Handles microphone and camera permissions for calls.
/// 
/// Usage:
/// ```dart
/// final hasPermission = await CallPermissions.requestPermissions(video: true);
/// if (!hasPermission) {
///   // Handle denial
/// }
/// ```

import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';
import '../core/constants/app_colors.dart';
import '../core/helpers/snackbar_helper.dart';
import '../components/indrive_dialog_template.dart';

class CallPermissions {
  /// Request necessary permissions for a call
  /// 
  /// Returns true if all required permissions are granted, false otherwise.
  static Future<bool> requestPermissions({required bool video}) async {
    // Check microphone permission first
    final micStatus = await Permission.microphone.status;
    
    if (!micStatus.isGranted) {
      // Show explanatory dialog before requesting permission
      final micGranted = await _showPermissionDialog(
        title: 'Microphone Permission Required',
        message: 'This app needs access to your microphone to make audio and video calls. Please grant the permission to continue.',
        permissionType: 'microphone',
      );
      
      if (!micGranted) {
        return false;
      }
    }

    // Request camera permission for video calls
    if (video) {
      final cameraStatus = await Permission.camera.status;
      
      if (!cameraStatus.isGranted) {
        // Show explanatory dialog before requesting permission
        final cameraGranted = await _showPermissionDialog(
          title: 'Camera Permission Required',
          message: 'This app needs access to your camera to make video calls. Please grant the permission to continue.',
          permissionType: 'camera',
        );
        
        if (!cameraGranted) {
          return false;
        }
      }
    }

    return true;
  }

  /// Show a dialog explaining why permission is needed, then request it
  static Future<bool> _showPermissionDialog({
    required String title,
    required String message,
    required String permissionType,
  }) async {
    // First check if permission is already granted
    Permission permission;
    if (permissionType == 'microphone') {
      permission = Permission.microphone;
    } else if (permissionType == 'camera') {
      permission = Permission.camera;
    } else {
      return false;
    }

    final status = await permission.status;
    if (status.isGranted) {
      return true;
    }

    // Show dialog explaining why permission is needed
    final result = await Get.dialog<bool>(
      InDriveDialogTemplate(
        title: title,
        message: message,
        primaryLabel: 'Grant Permission',
        onPrimary: () => Get.back(result: true),
        secondaryLabel: 'Cancel',
        onSecondary: () => Get.back(result: false),
      ),
      barrierDismissible: false,
    );

    if (result != true) {
      return false;
    }

    // Now request the permission
    final permissionStatus = await permission.request();

    if (permissionStatus.isGranted) {
      return true;
    }

    // Permission denied - show message with option to open settings
    if (permissionStatus.isPermanentlyDenied) {
      await Get.dialog(
        InDriveDialogTemplate(
          title: 'Permission Required',
          message: 'The $permissionType permission has been permanently denied. Please enable it in the app settings to make calls.',
          primaryLabel: 'Open Settings',
          onPrimary: () {
            Get.back();
            openAppSettings();
          },
          secondaryLabel: 'Cancel',
          onSecondary: () => Get.back(),
        ),
        barrierDismissible: false,
      );
    } else {
      SnackbarHelper.showSnackbar(
        title: 'Permission Denied',
        message: 'Please grant $permissionType permission to make calls.',
        backgroundColor: AppColors.error.withOpacity(0.9),
        colorText: AppColors.white,
      );
    }

    return false;
  }

  /// Check if permissions are granted (without requesting)
  static Future<bool> checkPermissions({required bool video}) async {
    final micGranted = await Permission.microphone.isGranted;
    
    if (!micGranted) return false;
    
    if (video) {
      final cameraGranted = await Permission.camera.isGranted;
      if (!cameraGranted) return false;
    }
    
    return true;
  }
}

