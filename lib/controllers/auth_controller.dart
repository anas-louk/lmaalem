import 'package:get/get.dart';
import '../core/services/auth_service.dart';
import '../data/models/user_model.dart';
import '../data/models/employee_model.dart';
import '../data/repositories/user_repository.dart';
import '../data/repositories/employee_repository.dart';
import '../core/constants/app_routes.dart' as AppRoutes;

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
        errorMessage.value = 'Aucun utilisateur connecté';
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
        Get.snackbar('Succès', 'Vous êtes maintenant un employé');
        return true;
      }

      return false;
    } catch (e) {
      errorMessage.value = e.toString();
      Get.snackbar('Erreur', errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Passer de Employee à Client
  Future<bool> switchToClient() async {
    try {
      if (currentUser.value == null) {
        errorMessage.value = 'Aucun utilisateur connecté';
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
        Get.snackbar('Succès', 'Vous êtes maintenant un client');
        return true;
      }

      return false;
    } catch (e) {
      errorMessage.value = e.toString();
      Get.snackbar('Erreur', errorMessage.value);
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
}
