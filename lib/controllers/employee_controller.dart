import 'package:get/get.dart';
import '../../data/models/employee_model.dart';
import '../../data/repositories/employee_repository.dart';

/// Controller pour gérer les employés (GetX)
class EmployeeController extends GetxController {
  final EmployeeRepository _employeeRepository = EmployeeRepository();

  // Observable states
  final RxList<EmployeeModel> employees = <EmployeeModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final Rx<EmployeeModel?> selectedEmployee = Rx<EmployeeModel?>(null);

  @override
  void onInit() {
    super.onInit();
    loadAvailableEmployees();
  }

  /// Charger tous les employés disponibles
  Future<void> loadAvailableEmployees() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final employeeList = await _employeeRepository.getAvailableEmployees();
      employees.assignAll(employeeList);
    } catch (e) {
      errorMessage.value = e.toString();
      Get.snackbar('Erreur', errorMessage.value);
    } finally {
      isLoading.value = false;
    }
  }

  /// Charger les employés par catégorie
  Future<void> loadEmployeesByCategory(String categoryId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final employeeList = await _employeeRepository.getEmployeesByCategory(categoryId);
      employees.assignAll(employeeList);
    } catch (e) {
      errorMessage.value = e.toString();
      Get.snackbar('Erreur', errorMessage.value);
    } finally {
      isLoading.value = false;
    }
  }

  /// Charger les employés par ville
  Future<void> loadEmployeesByVille(String ville) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final employeeList = await _employeeRepository.getEmployeesByVille(ville);
      employees.assignAll(employeeList);
    } catch (e) {
      errorMessage.value = e.toString();
      Get.snackbar('Erreur', errorMessage.value);
    } finally {
      isLoading.value = false;
    }
  }

  /// Rechercher des employés
  Future<void> searchEmployees(String query) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final employeeList = await _employeeRepository.searchEmployees(query);
      employees.assignAll(employeeList);
    } catch (e) {
      errorMessage.value = e.toString();
      Get.snackbar('Erreur', errorMessage.value);
    } finally {
      isLoading.value = false;
    }
  }

  /// Récupérer un employé par ID
  Future<EmployeeModel?> getEmployeeById(String employeeId) async {
    try {
      return await _employeeRepository.getEmployeeById(employeeId);
    } catch (e) {
      errorMessage.value = e.toString();
      return null;
    }
  }

  /// Créer un employé
  Future<bool> createEmployee(EmployeeModel employee) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await _employeeRepository.createEmployee(employee);
      await loadAvailableEmployees();
      Get.snackbar('Succès', 'Employé créé avec succès');
      return true;
    } catch (e) {
      errorMessage.value = e.toString();
      Get.snackbar('Erreur', errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Mettre à jour un employé
  Future<bool> updateEmployee(EmployeeModel employee) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await _employeeRepository.updateEmployee(employee);
      await loadAvailableEmployees();
      Get.snackbar('Succès', 'Employé mis à jour avec succès');
      return true;
    } catch (e) {
      errorMessage.value = e.toString();
      Get.snackbar('Erreur', errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Sélectionner un employé
  void selectEmployee(EmployeeModel employee) {
    selectedEmployee.value = employee;
  }
}

