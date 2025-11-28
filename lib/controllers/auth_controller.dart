import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/auth_service.dart';
import '../data/models/user_model.dart';
import '../data/models/employee_model.dart';
import '../data/repositories/user_repository.dart';
import '../data/repositories/employee_repository.dart';
import '../core/constants/app_routes.dart' as AppRoutes;
import '../core/services/background_notification_service.dart';
import '../core/helpers/snackbar_helper.dart';
import '../utils/battery_optimization.dart';
import 'request_controller.dart';

/// Controller pour gérer l'authentification (GetX)
class AuthController extends GetxController {
  final AuthService _authService = AuthService();
  final UserRepository _userRepository = UserRepository();
  final EmployeeRepository _employeeRepository = EmployeeRepository();

  // Observable states
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool isEmployee = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Écouter les changements d'authentification
    _authService.authStateChanges.listen((user) async {
      if (user != null) {
        await loadUser(user.uid);
      } else {
        // Stop streams when user logs out
        try {
          final requestController = Get.find<RequestController>();
          requestController.stopStreaming();
        } catch (e) {
          // RequestController might not be initialized, ignore
        }
        currentUser.value = null;
      }
    });
  }

  /// Charger les données de l'utilisateur
  Future<void> loadUser(String userId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final user = await _userRepository.getUserById(userId);
      currentUser.value = user;
      
      // Mettre à jour isEmployee
      if (user != null) {
        isEmployee.value = user.type.toLowerCase() == 'employee';
        
        // Save user info to SharedPreferences for background notifications
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('current_user_id', user.id);
          await prefs.setString('current_user_type', user.type.toLowerCase());
          debugPrint('[AuthController] Saved user info to SharedPreferences for background notifications');
          
          // Check and request battery optimization disable (only once per app install)
          // This ensures background notifications work properly
          final hasAskedBefore = prefs.getBool('battery_optimization_asked') ?? false;
          if (!hasAskedBefore) {
            // Wait a bit for the app to settle before showing the dialog
            Future.delayed(const Duration(seconds: 2), () async {
              final isIgnored = await BatteryOptimization.isIgnoringBatteryOptimizations();
              if (!isIgnored) {
                await BatteryOptimization.requestIgnoreBatteryOptimizations();
                // Mark as asked (even if user declined, we don't want to ask every time)
                await prefs.setBool('battery_optimization_asked', true);
              }
            });
          } else {
            // Still check silently and log if optimization is enabled
            final isIgnored = await BatteryOptimization.isIgnoringBatteryOptimizations();
            if (!isIgnored) {
              debugPrint('[AuthController] ⚠️ Battery optimization is enabled - background notifications may not work properly');
            }
          }
        } catch (e) {
          debugPrint('[AuthController] Error saving user info: $e');
        }
      }
      
      // Rediriger selon le type
      if (user != null && user.type.toLowerCase() == 'employee') {
        Get.offAllNamed(AppRoutes.AppRoutes.employeeDashboard);
      } else if (user != null) {
        Get.offAllNamed(AppRoutes.AppRoutes.clientDashboard);
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// Se connecter avec Google
  Future<bool> signInWithGoogle() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final userCredential = await _authService.signInWithGoogle();

      if (userCredential?.user != null) {
        await loadUser(userCredential!.user!.uid);
        return true;
      }
      return false;
    } catch (e) {
      errorMessage.value = e.toString();
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// S'inscrire
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final userCredential = await _authService.signUp(
        email: email,
        password: password,
        name: name,
      );

      if (userCredential?.user != null) {
        await loadUser(userCredential!.user!.uid);
        return true;
      }
      return false;
    } catch (e) {
      errorMessage.value = e.toString();
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Se connecter
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final userCredential = await _authService.signIn(
        email: email,
        password: password,
      );

      if (userCredential?.user != null) {
        await loadUser(userCredential!.user!.uid);
        return true;
      }
      return false;
    } catch (e) {
      errorMessage.value = e.toString();
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Se déconnecter
  Future<void> signOut() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      
      // Stop all active streams before signing out
      try {
        final requestController = Get.find<RequestController>();
        requestController.stopStreaming();
      } catch (e) {
        // RequestController might not be initialized, ignore
      }
      
      // Stop background notification polling
      try {
        await BackgroundNotificationService().reset();
      } catch (e) {
        // BackgroundNotificationService might not be initialized, ignore
      }
      
      // Clear user info from SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('current_user_id');
        await prefs.remove('current_user_type');
        debugPrint('[AuthController] Cleared user info from SharedPreferences');
      } catch (e) {
        debugPrint('[AuthController] Error clearing user info: $e');
      }
      
      await _authService.signOut();
      currentUser.value = null;
      Get.offAllNamed(AppRoutes.AppRoutes.login);
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// Réinitialiser le mot de passe
  Future<bool> resetPassword(String email) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await _authService.resetPassword(email);
      return true;
    } catch (e) {
      errorMessage.value = e.toString();
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Mettre à jour le profil
  Future<bool> updateProfile({
    String? name,
    String? photoUrl,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      await _authService.updateProfile(name: name, photoUrl: photoUrl);

      if (currentUser.value != null) {
        final updatedUser = currentUser.value!.copyWith(
          nomComplet: name ?? currentUser.value!.nomComplet,
          updatedAt: DateTime.now(),
        );

        await _userRepository.updateUser(updatedUser);
        currentUser.value = updatedUser;
      }

      return true;
    } catch (e) {
      errorMessage.value = e.toString();
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Passer directement de Client à Employee si l'Employee existe déjà
  Future<bool> switchToEmployeeDirectly() async {
    try {
      if (currentUser.value == null) {
        errorMessage.value = 'user_not_connected'.tr;
        return false;
      }

      isLoading.value = true;
      errorMessage.value = '';

      final success = await _authService.switchToEmployeeDirectly(
        userId: currentUser.value!.id,
      );

      if (success) {
        // Recharger l'utilisateur pour mettre à jour le type
        await loadUser(currentUser.value!.id);
        SnackbarHelper.showSuccess('now_employee'.tr);
        return true;
      }

      return false;
    } catch (e) {
      errorMessage.value = e.toString();
      SnackbarHelper.showError(errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Passer de Client à Employee
  Future<bool> switchToEmployee({
    required String categorieId,
    required String ville,
    required String competence,
    String? image,
    String? bio,
    String? gallery,
  }) async {
    try {
      if (currentUser.value == null) {
        errorMessage.value = 'user_not_connected'.tr;
        return false;
      }

      isLoading.value = true;
      errorMessage.value = '';

      final success = await _authService.switchToEmployee(
        userId: currentUser.value!.id,
        categorieId: categorieId,
        ville: ville,
        competence: competence,
        image: image,
        bio: bio,
        gallery: gallery,
      );

      if (success) {
        // Recharger l'utilisateur pour mettre à jour le type
        await loadUser(currentUser.value!.id);
        SnackbarHelper.showSuccess('now_employee'.tr);
        return true;
      }

      return false;
    } catch (e) {
      errorMessage.value = e.toString();
      SnackbarHelper.showError(errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Passer de Employee à Client
  Future<bool> switchToClient() async {
    try {
      if (currentUser.value == null) {
        errorMessage.value = 'user_not_connected'.tr;
        return false;
      }

      isLoading.value = true;
      errorMessage.value = '';

      final success = await _authService.switchToClient(
        userId: currentUser.value!.id,
      );

      if (success) {
        // Recharger l'utilisateur pour mettre à jour le type
        await loadUser(currentUser.value!.id);
        SnackbarHelper.showSuccess('now_client'.tr);
        return true;
      }

      return false;
    } catch (e) {
      errorMessage.value = e.toString();
      SnackbarHelper.showError(errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Récupérer l'Employee existant pour un utilisateur
  Future<EmployeeModel?> getExistingEmployee(String userId) async {
    try {
      return await _employeeRepository.getEmployeeById(userId);
    } catch (e) {
      // Si l'Employee n'existe pas, retourner null
      return null;
    }
  }

  /// Mettre à jour les informations de l'utilisateur
  Future<bool> updateUserInfo({
    required String nomComplet,
    required String localisation,
    required String tel,
    String? ville,
    String? competence,
    String? bio,
    String? categorieId,
  }) async {
    try {
      if (currentUser.value == null) {
        errorMessage.value = 'user_not_connected'.tr;
        return false;
      }

      isLoading.value = true;
      errorMessage.value = '';

      // Mettre à jour le UserModel
      final updatedUser = currentUser.value!.copyWith(
        nomComplet: nomComplet,
        localisation: localisation,
        tel: tel,
        updatedAt: DateTime.now(),
      );

      await _userRepository.updateUser(updatedUser);
      currentUser.value = updatedUser;

      // Si c'est un employé, mettre à jour aussi l'EmployeeModel
      if (currentUser.value!.type.toLowerCase() == 'employee') {
        final existingEmployee = await _employeeRepository.getEmployeeById(currentUser.value!.id);
        if (existingEmployee != null) {
          final updatedEmployee = existingEmployee.copyWith(
            nomComplet: nomComplet,
            localisation: localisation,
            tel: tel,
            ville: ville ?? existingEmployee.ville,
            competence: competence ?? existingEmployee.competence,
            bio: bio ?? existingEmployee.bio,
            categorieId: categorieId ?? existingEmployee.categorieId,
            updatedAt: DateTime.now(),
          );
          await _employeeRepository.updateEmployee(updatedEmployee);
        }
      }

      SnackbarHelper.showSuccess('profile_updated'.tr);
      return true;
    } catch (e) {
      errorMessage.value = e.toString();
      SnackbarHelper.showError(errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Supprimer le compte utilisateur
  Future<bool> deleteAccount() async {
    try {
      if (currentUser.value == null) {
        errorMessage.value = 'user_not_connected'.tr;
        return false;
      }

      isLoading.value = true;
      errorMessage.value = '';

      final userId = currentUser.value!.id;

      // Stop all active streams before deleting
      try {
        final requestController = Get.find<RequestController>();
        requestController.stopStreaming();
      } catch (e) {
        // RequestController might not be initialized, ignore
      }

      // Stop background notification polling
      try {
        await BackgroundNotificationService().reset();
      } catch (e) {
        // BackgroundNotificationService might not be initialized, ignore
      }

      // Clear user info from SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('current_user_id');
        await prefs.remove('current_user_type');
        debugPrint('[AuthController] Cleared user info from SharedPreferences');
      } catch (e) {
        debugPrint('[AuthController] Error clearing user info: $e');
      }

      // Delete account from Firebase
      await _authService.deleteAccount(userId);

      currentUser.value = null;
      Get.offAllNamed(AppRoutes.AppRoutes.login);
      SnackbarHelper.showSuccess('delete_account_success'.tr);
      return true;
    } catch (e) {
      errorMessage.value = e.toString();
      SnackbarHelper.showError('delete_account_error'.tr);
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}
