import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/employee_controller.dart';
import '../../core/constants/app_routes.dart' as AppRoutes;
import '../../components/loading_widget.dart';
import '../../components/empty_state.dart';
import '../../components/indrive_app_bar.dart';
import '../../components/indrive_section_title.dart';
import '../widgets/employee_card.dart';

/// Écran d'accueil
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final EmployeeController _employeeController = Get.put(EmployeeController());

    return Scaffold(
      appBar: InDriveAppBar(
        title: 'Employés disponibles',
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Get.toNamed(AppRoutes.AppRoutes.notifications),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Get.toNamed(AppRoutes.AppRoutes.profile),
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
              icon: Icons.people_outline,
              title: 'Aucun employé disponible',
              message: 'Réessayez plus tard ou rafraîchissez la liste.',
            );
          }

          return RefreshIndicator(
            onRefresh: _employeeController.loadAvailableEmployees,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              itemCount: _employeeController.employees.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 0),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: InDriveSectionTitle(
                      title: 'Trouve ton expert',
                      subtitle: 'Professionnels vérifiés près de chez toi',
                      actionText: 'Filtres',
                      onActionTap: _employeeController.loadAvailableEmployees,
                    ),
                  );
                }
                final employee = _employeeController.employees[index - 1];
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
