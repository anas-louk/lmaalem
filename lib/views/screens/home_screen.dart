import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/employee_controller.dart';
import '../../core/constants/app_routes.dart' as AppRoutes;
import '../../components/loading_widget.dart';
import '../../components/empty_state.dart';
import '../../components/indrive_app_bar.dart';
import '../../components/indrive_section_title.dart';
import '../../components/language_switcher.dart';
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
          const LanguageSwitcher(),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Obx(
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

            final bottomPadding = MediaQuery.of(context).padding.bottom;
            return RefreshIndicator(
              onRefresh: _employeeController.loadAvailableEmployees,
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + bottomPadding),
              itemCount: _employeeController.employees.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 0),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: InDriveSectionTitle(
                      title: 'find_expert'.tr,
                      subtitle: 'verified_professionals_nearby'.tr,
                      actionText: 'filters'.tr,
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
      ),
    );
  }
}
