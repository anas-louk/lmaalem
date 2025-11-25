import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';
import '../core/constants/app_routes.dart' as AppRoutes;
import '../views/screens/history_screen.dart';

/// Sidebar widget avec historique, profil et déconnexion
class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController _authController = Get.find<AuthController>();

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header avec avatar et nom
            Obx(
              () {
                final user = _authController.currentUser.value;
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          user?.nomComplet.isNotEmpty == true
                              ? user!.nomComplet[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 32,
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user?.nomComplet ?? 'Utilisateur',
                        style: AppTextStyles.h3,
                        textAlign: TextAlign.center,
                      ),
                      if (user != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          user.type.toLowerCase() == 'client'
                              ? 'client_type'.tr
                              : 'employee_type'.tr,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            // Menu items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Historique
                  ListTile(
                    leading: const Icon(Icons.history, color: AppColors.primary),
                    title: Text('history'.tr),
                    onTap: () {
                      Navigator.pop(context);
                      Get.to(() => const HistoryScreen());
                    },
                  ),
                  const Divider(),
                  // Profil
                  ListTile(
                    leading: const Icon(Icons.person, color: AppColors.primary),
                    title: Text('profile'.tr),
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(AppRoutes.AppRoutes.profile);
                    },
                  ),
                  const Divider(),
                ],
              ),
            ),
            // Déconnexion button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Obx(
                () => SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _authController.isLoading.value
                        ? null
                        : () async {
                            Navigator.pop(context);
                            await _authController.signOut();
                          },
                    icon: const Icon(Icons.logout),
                    label: Text('logout'.tr),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

