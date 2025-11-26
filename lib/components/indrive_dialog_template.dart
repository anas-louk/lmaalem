import 'package:flutter/material.dart';
import '../core/constants/app_text_styles.dart';
import '../core/constants/app_colors.dart';
import 'indrive_button.dart';

class InDriveDialogTemplate extends StatelessWidget {
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool danger;
  final IconData? icon;

  const InDriveDialogTemplate({
    super.key,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.danger = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final IconData displayIcon = icon ?? 
        (danger ? Icons.warning_rounded : Icons.info_rounded);
    final Color iconColor = danger ? AppColors.error : AppColors.primary;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.nightSurface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: danger 
                ? AppColors.error.withOpacity(0.3)
                : AppColors.primary.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 0,
              offset: const Offset(0, 20),
            ),
            BoxShadow(
              color: (danger ? AppColors.error : AppColors.primary).withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icône avec fond circulaire
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: iconColor.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    displayIcon,
                    color: iconColor,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Titre
              Center(
                child: Text(
                  title,
                  style: AppTextStyles.h3.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              // Message
              Center(
                child: Text(
                  message,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white70,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 28),
              // Boutons
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InDriveButton(
                    label: primaryLabel,
                    onPressed: onPrimary,
                    variant: danger
                        ? InDriveButtonVariant.ghost
                        : InDriveButtonVariant.primary,
                  ),
                  if (secondaryLabel != null) ...[
                    const SizedBox(height: 12),
                    InDriveButton(
                      label: secondaryLabel!,
                      onPressed: onSecondary,
                      variant: InDriveButtonVariant.ghost,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

