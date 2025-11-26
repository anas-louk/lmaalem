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
      backgroundColor: AppColors.night,
      width: MediaQuery.of(context).size.width * 0.85,
      child: SafeArea(
        child: Column(
          children: [
            // Header avec avatar et nom (design ultra-moderne)
            Obx(
              () {
                final user = _authController.currentUser.value;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(0, 32, 0, 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withOpacity(0.25),
                        AppColors.primaryDark.withOpacity(0.15),
                        AppColors.night,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white10,
                        width: 1,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                      // Avatar avec effet de brillance
                      Stack(
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primary,
                                  AppColors.primaryDark,
                                  AppColors.primary.withOpacity(0.8),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.5),
                                  blurRadius: 24,
                                  spreadRadius: 4,
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 12,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.nightSurface,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    user?.nomComplet.isNotEmpty == true
                                        ? user!.nomComplet[0].toUpperCase()
                                        : 'U',
                                    style: AppTextStyles.h1.copyWith(
                                      color: AppColors.primaryLight,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Badge de statut (optionnel)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.success,
                                border: Border.all(
                                  color: AppColors.night,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.success.withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Nom
                      Text(
                        user?.nomComplet ?? 'Utilisateur',
                        style: AppTextStyles.h3.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (user != null) ...[
                        const SizedBox(height: 8),
                        // Badge de type avec gradient
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.3),
                                AppColors.primaryDark.withOpacity(0.2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.4),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.2),
                                blurRadius: 12,
                                spreadRadius: 0,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                user.type.toLowerCase() == 'client'
                                    ? Icons.person_outline_rounded
                                    : Icons.work_outline_rounded,
                                size: 16,
                                color: AppColors.primaryLight,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                user.type.toLowerCase() == 'client'
                                    ? 'client_type'.tr
                                    : 'employee_type'.tr,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primaryLight,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Informations supplémentaires
                        if (user.tel.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.phone_rounded,
                                size: 14,
                                color: Colors.white54,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                user.tel,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                );
              },
            ),
            // Menu items (design moderne)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                children: [
                  // Section title
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 12, top: 8),
                    child: Text(
                      'Navigation',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white54,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  // Historique
                  _buildMenuItem(
                    context: context,
                    icon: Icons.history_rounded,
                    title: 'history'.tr,
                    subtitle: 'Voir l\'historique',
                    onTap: () {
                      Navigator.pop(context);
                      Get.to(() => const HistoryScreen());
                    },
                  ),
                  const SizedBox(height: 8),
                  // Profil
                  _buildMenuItem(
                    context: context,
                    icon: Icons.person_rounded,
                    title: 'profile'.tr,
                    subtitle: 'edit_profile'.tr,
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(AppRoutes.AppRoutes.profile);
                    },
                  ),
                ],
              ),
            ),
            // Séparateur
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white10,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            // Déconnexion button (design moderne)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Obx(
                () => Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: _authController.isLoading.value
                          ? [
                              AppColors.error.withOpacity(0.1),
                              AppColors.error.withOpacity(0.05),
                            ]
                          : [
                              AppColors.error.withOpacity(0.2),
                              AppColors.error.withOpacity(0.1),
                            ],
                    ),
                    border: Border.all(
                      color: AppColors.error.withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: _authController.isLoading.value
                        ? null
                        : [
                            BoxShadow(
                              color: AppColors.error.withOpacity(0.2),
                              blurRadius: 16,
                              spreadRadius: 0,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _authController.isLoading.value
                          ? null
                          : () async {
                              Navigator.pop(context);
                              await _authController.signOut();
                            },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_authController.isLoading.value)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.error),
                                ),
                              )
                            else
                              Icon(
                                Icons.logout_rounded,
                                color: AppColors.error,
                                size: 22,
                              ),
                            const SizedBox(width: 12),
                            Text(
                              'logout'.tr,
                              style: AppTextStyles.buttonLarge.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.nightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white10,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          splashColor: AppColors.primary.withOpacity(0.1),
          highlightColor: AppColors.primary.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // Icône avec fond gradient
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withOpacity(0.2),
                        AppColors.primaryDark.withOpacity(0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.primaryLight,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                // Titre et sous-titre
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Flèche
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.white30,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


