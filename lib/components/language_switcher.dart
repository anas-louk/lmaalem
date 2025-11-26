import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/language_controller.dart';
import '../core/constants/app_colors.dart';

/// Widget pour changer la langue de l'application
class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final languageController = Get.find<LanguageController>();
    
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.language_rounded,
        color: Colors.white,
      ),
      color: AppColors.nightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      elevation: 8,
      onSelected: (languageCode) {
        languageController.changeLanguage(languageCode);
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'fr_FR',
          child: Obx(
            () => Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: languageController.currentLanguage.value == 'fr_FR'
                    ? AppColors.primary.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  if (languageController.currentLanguage.value == 'fr_FR')
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primaryLight,
                      size: 20,
                    ),
                  if (languageController.currentLanguage.value != 'fr_FR')
                    const SizedBox(width: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Français',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
        PopupMenuItem(
          value: 'ar_SA',
          child: Obx(
            () => Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: languageController.currentLanguage.value == 'ar_SA'
                    ? AppColors.primary.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  if (languageController.currentLanguage.value == 'ar_SA')
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primaryLight,
                      size: 20,
                    ),
                  if (languageController.currentLanguage.value != 'ar_SA')
                    const SizedBox(width: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'العربية',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

