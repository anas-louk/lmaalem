import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:io';
import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';
import 'indrive_button.dart';
import 'custom_text_field.dart';

/// Formulaire de demande glissant depuis le bas
class DraggableRequestForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController descriptionController;
  final ValueNotifier<String?> selectedCategorieIdNotifier;
  final ValueNotifier<List<File>> selectedImagesNotifier;
  final Function() onPickImages;
  final Function() onSubmit;
  final ValueNotifier<bool> isSubmittingNotifier;
  final List<dynamic> categories;
  final bool isLoadingCategories;

  const DraggableRequestForm({
    super.key,
    required this.formKey,
    required this.descriptionController,
    required this.selectedCategorieIdNotifier,
    required this.selectedImagesNotifier,
    required this.onPickImages,
    required this.onSubmit,
    required this.isSubmittingNotifier,
    required this.categories,
    required this.isLoadingCategories,
  });

  @override
  State<DraggableRequestForm> createState() => _DraggableRequestFormState();
}

class _DraggableRequestFormState extends State<DraggableRequestForm> {
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.3, 0.5, 0.95],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.nightSurface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 30,
                spreadRadius: 0,
                offset: const Offset(0, -20),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                children: [
                  // Handle pour glisser
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Titre
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_circle_outline_rounded,
                                size: 20,
                                color: AppColors.primaryLight,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'new_request'.tr,
                                style: AppTextStyles.h3.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Contenu scrollable
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      child: Form(
                        key: widget.formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Sélecteur de catégories
                            _buildCategorySelector(),
                            const SizedBox(height: 24),
                            // Formulaire de description
                            _buildDescriptionForm(),
                            const SizedBox(height: 24),
                            // Bouton de soumission
                            _buildSubmitButton(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// Sélecteur de catégories (thème sombre)
  Widget _buildCategorySelector() {
    if (widget.isLoadingCategories) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryLight,
          strokeWidth: 2,
        ),
      );
    }

    if (widget.categories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.nightSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white10,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.category_outlined,
              size: 48,
              color: Colors.white70,
            ),
            const SizedBox(height: 12),
            Text(
              'no_categories'.tr,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header avec titre
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.category_rounded,
                    size: 18,
                    color: AppColors.primaryLight,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'select_category'.tr,
                    style: AppTextStyles.h4.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Grille verticale scrollable des catégories (3 colonnes)
        SizedBox(
          height: 200,
          child: GridView.builder(
            scrollDirection: Axis.vertical,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            itemCount: widget.categories.length,
            itemBuilder: (context, index) {
              final categorie = widget.categories[index];
              return ValueListenableBuilder<String?>(
                valueListenable: widget.selectedCategorieIdNotifier,
                builder: (context, selectedId, _) {
                  final isSelected = selectedId == categorie.id;
                  return GestureDetector(
                    onTap: () {
                      widget.selectedCategorieIdNotifier.value = categorie.id;
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icône circulaire
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: isSelected
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppColors.primary,
                                        AppColors.primaryDark,
                                      ],
                                    )
                                  : null,
                              color: isSelected ? null : AppColors.nightSecondary,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary.withOpacity(0.6)
                                    : Colors.white10,
                                width: isSelected ? 3 : 2,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.5),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 6,
                                        spreadRadius: 0,
                                      ),
                                    ],
                            ),
                            child: Center(
                              child: Text(
                                categorie.nom.substring(0, 1).toUpperCase(),
                                style: AppTextStyles.h4.copyWith(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white70,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Nom de la catégorie
                          Flexible(
                            child: Text(
                              categorie.nom,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isSelected
                                    ? AppColors.primaryLight
                                    : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Formulaire de description (thème sombre)
  Widget _buildDescriptionForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 18,
                    color: AppColors.primaryLight,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'request_description_label'.tr,
                    style: AppTextStyles.h4.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: widget.descriptionController,
          hint: 'request_description_hint'.tr,
          maxLines: 5,
          fillColor: AppColors.nightSecondary,
          textColor: Colors.white,
          labelColor: Colors.white,
          hintColor: Colors.white54,
          iconColor: Colors.white70,
          borderColor: Colors.white10,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'description_required'.tr;
            }
            return null;
          },
        ),
        ValueListenableBuilder<List<File>>(
          valueListenable: widget.selectedImagesNotifier,
          builder: (context, images, _) {
            if (images.isEmpty) return const SizedBox.shrink();
            return Column(
              children: [
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                images[index],
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  final newImages = List<File>.from(images);
                                  newImages.removeAt(index);
                                  widget.selectedImagesNotifier.value = newImages;
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: AppColors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: OutlinedButton.icon(
            onPressed: widget.onPickImages,
            icon: Icon(
              Icons.add_photo_alternate_rounded,
              color: AppColors.primaryLight,
            ),
            label: Text(
              'add_images'.tr,
              style: const TextStyle(
                color: Colors.white,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              side: BorderSide.none,
              backgroundColor: AppColors.primary.withOpacity(0.1),
            ),
          ),
        ),
      ],
    );
  }

  /// Bouton de soumission
  Widget _buildSubmitButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.isSubmittingNotifier,
      builder: (context, isSubmitting, _) {
        return InDriveButton(
          label: isSubmitting ? 'submitting'.tr : 'confirm_request'.tr,
          onPressed: isSubmitting ? null : widget.onSubmit,
          variant: InDriveButtonVariant.primary,
        );
      },
    );
  }
}

