import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/mission_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_routes.dart' as AppRoutes;
import '../../components/loading_widget.dart';
import '../../components/empty_state.dart';

/// Dashboard Employee
class EmployeeDashboardScreen extends StatelessWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController _authController = Get.find<AuthController>();
    final MissionController _missionController = Get.put(MissionController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord Employé'),
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
          final user = _authController.currentUser.value;

          if (user == null) {
            return const LoadingWidget();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Welcome Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'Bonjour, ${user.nomComplet}',
                          style: AppTextStyles.h2,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Vous êtes connecté en tant qu\'Employé',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Missions Section
                Text(
                  'Mes Missions Assignées',
                  style: AppTextStyles.h3,
                ),
                const SizedBox(height: 16),

                Obx(
                  () {
                    if (_missionController.isLoading.value) {
                      return const LoadingWidget();
                    }

                    // Charger les missions de l'employé
                    if (user.id.isNotEmpty) {
                      _missionController.loadMissionsByEmployee(user.id);
                    }

                    if (_missionController.missions.isEmpty) {
                      return EmptyState(
                        icon: Icons.work_outline,
                        title: 'Aucune mission',
                        message: 'Vous n\'avez pas encore de missions assignées',
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _missionController.missions.length,
                      itemBuilder: (context, index) {
                        final mission = _missionController.missions[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text('Mission #${mission.id.substring(0, 8)}'),
                            subtitle: Text(
                              'Prix: ${mission.prixMission.toStringAsFixed(2)} €\n'
                              'Statut: ${mission.statutMission}\n'
                              'Date: ${mission.dateStart.toString().substring(0, 10)}',
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(mission.statutMission),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                mission.statutMission,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            onTap: () {
                              _missionController.selectMission(mission);
                              Get.toNamed(AppRoutes.AppRoutes.missionDetail);
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String statut) {
    switch (statut.toLowerCase()) {
      case 'pending':
        return AppColors.warning;
      case 'in progress':
        return AppColors.info;
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.grey;
    }
  }
}

