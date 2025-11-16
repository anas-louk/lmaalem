import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/categorie_controller.dart';
import '../../controllers/employee_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_routes.dart' as AppRoutes;
import '../../components/loading_widget.dart';
import '../../components/empty_state.dart';

/// Écran des catégories pour les clients
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final CategorieController _categorieController = Get.put(CategorieController());
    final EmployeeController _employeeController = Get.put(EmployeeController());

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
                    // Naviguer vers la page de soumission de demande
                    Get.toNamed(
                      AppRoutes.AppRoutes.requestSubmission,
                      arguments: categorie.id,
                    );
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

