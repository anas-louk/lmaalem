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
      icon: const Icon(Icons.language),
      onSelected: (languageCode) {
        languageController.changeLanguage(languageCode);
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'fr_FR',
          child: Obx(
            () => Row(
              children: [
                if (languageController.currentLanguage.value == 'fr_FR')
                  const Icon(Icons.check, color: AppColors.primary, size: 20),
                if (languageController.currentLanguage.value != 'fr_FR')
                  const SizedBox(width: 20),
                const SizedBox(width: 8),
                const Text('Français'),
              ],
            ),
          ),
        ),
        PopupMenuItem(
          value: 'ar_SA',
          child: Obx(
            () => Row(
              children: [
                if (languageController.currentLanguage.value == 'ar_SA')
                  const Icon(Icons.check, color: AppColors.primary, size: 20),
                if (languageController.currentLanguage.value != 'ar_SA')
                  const SizedBox(width: 20),
                const SizedBox(width: 8),
                const Text('العربية'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

