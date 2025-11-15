import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/categorie_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../components/custom_button.dart';
import '../../components/custom_text_field.dart';

/// Écran de profil
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController _authController = Get.find<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
      ),
      body: Obx(
        () {
          final user = _authController.currentUser.value;

          if (user == null) {
            return const Center(
              child: Text('Utilisateur non connecté'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 60,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    user.nomComplet.isNotEmpty ? user.nomComplet[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 48,
                      color: AppColors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Name
                Text(
                  user.nomComplet,
                  style: AppTextStyles.h2,
                ),
                const SizedBox(height: 8),

                // Type
                Text(
                  'Type: ${user.type}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                // Localisation
                Text(
                  'Localisation: ${user.localisation}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                // Téléphone
                Text(
                  'Téléphone: ${user.tel}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 48),

                // Switch to Employee button (only for Clients)
                if (user.type.toLowerCase() == 'client')
                  Obx(
                    () => CustomButton(
                      onPressed: _authController.isLoading.value
                          ? null
                          : () {
                              _showSwitchToEmployeeDialog(context, _authController);
                            },
                      text: 'Devenir Employé',
                      isLoading: _authController.isLoading.value,
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                if (user.type.toLowerCase() == 'client') const SizedBox(height: 16),

                // Switch to Client button (only for Employees)
                if (user.type.toLowerCase() == 'employee')
                  Obx(
                    () => CustomButton(
                      onPressed: _authController.isLoading.value
                          ? null
                          : () {
                              _showSwitchToClientDialog(context, _authController);
                            },
                      text: 'Devenir Client',
                      isLoading: _authController.isLoading.value,
                      backgroundColor: AppColors.secondary,
                    ),
                  ),
                if (user.type.toLowerCase() == 'employee') const SizedBox(height: 16),

                // Logout button
                Obx(
                  () => CustomButton(
                    onPressed: () async {
                      await _authController.signOut();
                    },
                    text: 'Se déconnecter',
                    isLoading: _authController.isLoading.value,
                    backgroundColor: AppColors.error,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSwitchToEmployeeDialog(
    BuildContext context,
    AuthController authController,
  ) async {
    final villeController = TextEditingController();
    final competenceController = TextEditingController();
    final categorieController = Get.put(CategorieController());
    final selectedCategorieId = Rx<String?>(null);

    // Charger les catégories si elles ne sont pas déjà chargées
    if (categorieController.categories.isEmpty) {
      await categorieController.loadAllCategories();
    }

    // Vérifier si l'Employee existe déjà et pré-remplir les champs
    final currentUser = authController.currentUser.value;
    if (currentUser != null) {
      final existingEmployee = await authController.getExistingEmployee(currentUser.id);
      if (existingEmployee != null) {
        // Pré-remplir avec les données existantes
        selectedCategorieId.value = existingEmployee.categorieId;
        villeController.text = existingEmployee.ville;
        competenceController.text = existingEmployee.competence;
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Devenir Employé'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(
                  () => DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Catégorie',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedCategorieId.value,
                    items: categorieController.categories.map((categorie) {
                      return DropdownMenuItem<String>(
                        value: categorie.id,
                        child: Text(categorie.nom),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedCategorieId.value = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'La catégorie est requise';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),
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
                        if (selectedCategorieId.value != null &&
                            villeController.text.isNotEmpty &&
                            competenceController.text.isNotEmpty) {
                          final success = await authController.switchToEmployee(
                            categorieId: selectedCategorieId.value!,
                            ville: villeController.text,
                            competence: competenceController.text,
                          );

                          if (success) {
                            Get.back(); // Close dialog
                            // The redirect will happen automatically via loadUser
                          }
                        } else {
                          Get.snackbar(
                            'Erreur',
                            'Veuillez remplir tous les champs',
                          );
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
      ),
    );
  }

  void _showSwitchToClientDialog(
    BuildContext context,
    AuthController authController,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Devenir Client'),
        content: const Text(
          'Êtes-vous sûr de vouloir passer en mode Client ?\n\n'
          'Votre profil employé sera conservé et vous pourrez le réactiver à tout moment.',
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
                      final success = await authController.switchToClient();

                      if (success) {
                        Get.back(); // Close dialog
                        // The redirect will happen automatically via loadUser
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
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
