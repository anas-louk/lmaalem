import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';

enum InDriveButtonVariant { primary, secondary, ghost }

class InDriveButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final InDriveButtonVariant variant;
  final bool isLoading;
  final IconData? leadingIcon;
  final double height;

  const InDriveButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = InDriveButtonVariant.primary,
    this.isLoading = false,
    this.leadingIcon,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null || isLoading;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    Color background;
    Color foreground;
    BorderSide border = BorderSide.none;

    switch (variant) {
      case InDriveButtonVariant.primary:
        background = disabled ? AppColors.primary.withOpacity(0.6) : AppColors.primary;
        foreground = AppColors.white;
        break;
      case InDriveButtonVariant.secondary:
        background = scheme.surfaceVariant;
        foreground = scheme.onSurface;
        break;
      case InDriveButtonVariant.ghost:
        background = AppColors.error.withOpacity(0.15);
        foreground = AppColors.error;
        border = BorderSide(
          color: AppColors.error.withOpacity(0.4),
          width: 1.5,
        );
        break;
    }

    final child = isLoading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leadingIcon != null) ...[
                Icon(leadingIcon, size: 20, color: foreground),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: AppTextStyles.buttonLarge.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: disabled ? 0.7 : 1,
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
            border: border == BorderSide.none ? null : Border.fromBorderSide(border),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: disabled ? null : onPressed,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

