import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_routes.dart' as AppRoutes;
import '../../components/custom_button.dart';

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

                // Settings button
                CustomButton(
                  onPressed: () {
                      Get.toNamed(AppRoutes.AppRoutes.settings);
                  },
                  text: 'Paramètres',
                ),
                const SizedBox(height: 16),

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
}

