import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/employee_controller.dart';
import '../../core/constants/app_routes.dart' as AppRoutes;
import '../../components/loading_widget.dart';
import '../../components/empty_state.dart';
import '../widgets/employee_card.dart';

/// Écran d'accueil
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final EmployeeController _employeeController = Get.put(EmployeeController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employés Disponibles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Get.toNamed(AppRoutes.AppRoutes.profile);
            },
          ),
        ],
      ),
      body: Obx(
        () {
          if (_employeeController.isLoading.value) {
            return const LoadingWidget();
          }

          if (_employeeController.employees.isEmpty) {
            return EmptyState(
              icon: Icons.people_outlined,
              title: 'Aucun employé disponible',
              message: 'Aucun employé disponible pour le moment',
            );
          }

          return RefreshIndicator(
            onRefresh: _employeeController.loadAvailableEmployees,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _employeeController.employees.length,
              itemBuilder: (context, index) {
                final employee = _employeeController.employees[index];
                return EmployeeCard(
                  employee: employee,
                  onTap: () {
                    _employeeController.selectEmployee(employee);
                    Get.toNamed(AppRoutes.AppRoutes.employeeDetail);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
