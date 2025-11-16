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

/// Écran des catégories pour les clients
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  Future<void> _checkAndNavigate(String categorieId) async {
    final AuthController _authController = Get.find<AuthController>();
    final RequestController _requestController = Get.put(RequestController());

    final user = _authController.currentUser.value;
    if (user == null) {
      Get.snackbar('Erreur', 'Vous devez être connecté');
      return;
    }

    // Vérifier si le client a déjà une demande active
    final hasActive = await _requestController.hasActiveRequest(user.id);
    
    if (hasActive) {
      final activeRequest = await _requestController.getActiveRequest(user.id);
      final statusText = activeRequest?.statut.toLowerCase() == 'pending' 
          ? 'en attente' 
          : 'acceptée';
      
      Get.snackbar(
        'Demande en cours',
        'Vous avez déjà une demande $statusText. Veuillez attendre qu\'elle soit terminée avant d\'en créer une nouvelle.',
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
      appBar: AppBar(
        title: const Text('Catégories'),
      ),
      body: Obx(
        () {
          if (_categorieController.isLoading.value) {
            return const LoadingWidget();
          }

          if (_categorieController.categories.isEmpty) {
            return EmptyState(
              icon: Icons.category_outlined,
              title: 'Aucune catégorie',
              message: 'Aucune catégorie disponible pour le moment',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _categorieController.categories.length,
            itemBuilder: (context, index) {
              final categorie = _categorieController.categories[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      categorie.nom[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    categorie.nom,
                    style: AppTextStyles.h4,
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  onTap: () {
                    _checkAndNavigate(categorie.id);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

