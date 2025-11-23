import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';

/// Champ de texte personnalisé réutilisable
class CustomTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final int? maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final void Function(String)? onChanged;
  final Color? fillColor;
  final Color? labelColor;
  final Color? textColor;
  final Color? hintColor;
  final Color? iconColor;
  final Color? borderColor;

  const CustomTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.enabled = true,
    this.onChanged,
    this.fillColor,
    this.labelColor,
    this.textColor,
    this.hintColor,
    this.iconColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: labelColor ?? AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          enabled: enabled,
          onChanged: onChanged,
          style: TextStyle(
            color: textColor ?? AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: hintColor ?? AppColors.textTertiary,
            ),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: iconColor ?? AppColors.textSecondary)
                : null,
            suffixIcon: suffixIcon != null
                ? IconButton(
                    icon: Icon(
                      suffixIcon,
                      color: iconColor ?? AppColors.textSecondary,
                    ),
                    onPressed: onSuffixTap,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor ?? AppColors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor ?? AppColors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
            filled: true,
            fillColor: fillColor ?? AppColors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}

