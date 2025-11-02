import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/mission_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_routes.dart' as AppRoutes;
import '../../components/custom_button.dart';
import '../../components/custom_text_field.dart';
import '../../components/loading_widget.dart';
import '../../components/empty_state.dart';

/// Dashboard Client
class ClientDashboardScreen extends StatelessWidget {
  const ClientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController _authController = Get.find<AuthController>();
    final MissionController _missionController = Get.put(MissionController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord Client'),
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
                          'Vous êtes connecté en tant que Client',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Switch to Employee Button
                CustomButton(
                  onPressed: () {
                    _showSwitchToEmployeeDialog(context, _authController);
                  },
                  text: 'Devenir Employé',
                  backgroundColor: AppColors.primary,
                ),
                const SizedBox(height: 24),

                // Missions Section
                Text(
                  'Mes Missions',
                  style: AppTextStyles.h3,
                ),
                const SizedBox(height: 16),

                Obx(
                  () {
                    if (_missionController.isLoading.value) {
                      return const LoadingWidget();
                    }

                    // Charger les missions du client
                    if (user.id.isNotEmpty) {
                      _missionController.loadMissionsByClient(user.id);
                    }

                    if (_missionController.missions.isEmpty) {
                      return EmptyState(
                        icon: Icons.work_outline,
                        title: 'Aucune mission',
                        message: 'Vous n\'avez pas encore de missions',
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
                              'Statut: ${mission.statutMission}',
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: AppColors.primary,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.toNamed(AppRoutes.AppRoutes.addMission);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showSwitchToEmployeeDialog(
    BuildContext context,
    AuthController authController,
  ) {
    final villeController = TextEditingController();
    final competenceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Devenir Employé'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(
              controller: villeController,
              label: 'Ville',
              hint: 'Ex: Casablanca',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'La ville est requise';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: competenceController,
              label: 'Compétence',
              hint: 'Ex: Plomberie, Électricité, etc.',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'La compétence est requise';
                }
                return null;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Annuler'),
          ),
          Obx(
            () => ElevatedButton(
              onPressed: authController.isLoading.value
                  ? null
                  : () async {
                      if (villeController.text.isNotEmpty &&
                          competenceController.text.isNotEmpty) {
                        final success = await authController.switchToEmployee(
                          ville: villeController.text,
                          competence: competenceController.text,
                        );

                        if (success) {
                          Get.back();
                        }
                      }
                    },
              child: authController.isLoading.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirmer'),
            ),
          ),
        ],
      ),
    );
  }
}

