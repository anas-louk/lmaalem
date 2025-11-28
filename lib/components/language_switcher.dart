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
    
    final colorScheme = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.language_rounded,
        color: colorScheme.onSurface,
      ),
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.primary.withOpacity(0.3),
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
                    ? colorScheme.primary.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  if (languageController.currentLanguage.value == 'fr_FR')
                    Icon(
                      Icons.check_circle_rounded,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                  if (languageController.currentLanguage.value != 'fr_FR')
                    const SizedBox(width: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Français',
                    style: TextStyle(color: colorScheme.onSurface),
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
                    ? colorScheme.primary.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  if (languageController.currentLanguage.value == 'ar_SA')
                    Icon(
                      Icons.check_circle_rounded,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                  if (languageController.currentLanguage.value != 'ar_SA')
                    const SizedBox(width: 20),
                  const SizedBox(width: 8),
                  Text(
                    'العربية',
                    style: TextStyle(color: colorScheme.onSurface),
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

