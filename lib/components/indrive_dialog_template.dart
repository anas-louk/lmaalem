import 'package:flutter/material.dart';
import '../core/constants/app_text_styles.dart';
import 'indrive_button.dart';

class InDriveDialogTemplate extends StatelessWidget {
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool danger;

  const InDriveDialogTemplate({
    super.key,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.h3.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InDriveButton(
                  label: primaryLabel,
                  onPressed: onPrimary,
                  variant: danger
                      ? InDriveButtonVariant.secondary
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
    );
  }
}

