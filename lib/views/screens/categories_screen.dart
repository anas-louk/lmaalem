import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/categorie_controller.dart';
import '../../controllers/request_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_routes.dart' as AppRoutes;
import '../../components/loading_widget.dart';
import '../../components/empty_state.dart';
import '../../core/helpers/snackbar_helper.dart';

/// Écran des catégories pour les clients
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  Future<void> _checkAndNavigate(String categorieId) async {
    final AuthController _authController = Get.find<AuthController>();
    final RequestController _requestController = Get.put(RequestController());

    final user = _authController.currentUser.value;
    if (user == null) {
      SnackbarHelper.showError('must_be_connected'.tr);
      return;
    }

    // Vérifier si le client a déjà une demande active
    final hasActive = await _requestController.hasActiveRequest(user.id);
    
    if (hasActive) {
      final activeRequest = await _requestController.getActiveRequest(user.id);
      final statusText = activeRequest?.statut.toLowerCase() == 'pending' 
          ? 'status_pending'.tr 
          : 'status_accepted'.tr;
      
      SnackbarHelper.showSnackbar(
        title: 'request_in_progress'.tr,
        message: 'request_in_progress_message'.tr.replaceAll('{status}', statusText),
        duration: const Duration(seconds: 4),
        backgroundColor: AppColors.warning.withOpacity(0.9),
        colorText: AppColors.white,
      );
      return;
    }

    // Si pas de demande active, naviguer vers la page de soumission
    Get.toNamed(
      AppRoutes.AppRoutes.requestSubmission,
      arguments: categorieId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final CategorieController _categorieController = Get.put(CategorieController());

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          'categories'.tr,
          style: AppTextStyles.h3.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        actionsIconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
      ),
      body: Obx(
        () {
          if (_categorieController.isLoading.value) {
            return const LoadingWidget();
          }

            if (_categorieController.categories.isEmpty) {
              return EmptyState(
                icon: Icons.category_outlined,
                title: 'no_categories'.tr,
                message: 'no_categories_message'.tr,
              );
            }

          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemCount: _categorieController.categories.length,
            itemBuilder: (context, index) {
              final categorie = _categorieController.categories[index];
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 0,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      _checkAndNavigate(categorie.id);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primary,
                                  AppColors.primaryDark,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.4),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                categorie.nom[0].toUpperCase(),
                                style: AppTextStyles.h2.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            categorie.nom,
                            style: AppTextStyles.h4.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

