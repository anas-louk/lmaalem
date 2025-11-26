import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';

/// Thème global inspiré d'InDrive (light & dark)
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final Color background = isDark ? AppColors.night : AppColors.background;
    final Color surface = isDark ? AppColors.nightSurface : AppColors.surface;
    final Color onBackground =
        isDark ? AppColors.white : AppColors.textPrimary;
    final Color onSurface = isDark ? Colors.white : AppColors.textPrimary;
    final Color divider = isDark ? Colors.white12 : AppColors.grey.withOpacity(0.2);

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: AppColors.white,
      secondary: AppColors.secondary,
      onSecondary: AppColors.white,
      error: AppColors.error,
      onError: AppColors.white,
      background: background,
      onBackground: onBackground,
      surface: surface,
      onSurface: onSurface,
      outline: divider,
      shadow: Colors.black.withOpacity(isDark ? 0.6 : 0.12),
      surfaceVariant: isDark ? AppColors.nightSecondary : AppColors.greyLight,
      inverseSurface: AppColors.primaryDark,
      inversePrimary: AppColors.primaryLight,
      tertiary: AppColors.accent,
      onTertiary: AppColors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.h3.copyWith(color: onSurface),
        iconTheme: IconThemeData(color: onSurface),
        actionsIconTheme: IconThemeData(color: onSurface),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.nightSecondary : AppColors.white,
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: isDark ? Colors.white60 : AppColors.textTertiary,
        ),
        labelStyle: AppTextStyles.bodyMedium.copyWith(
          color: onSurface,
          fontWeight: FontWeight.w600,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: AppTextStyles.buttonLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          textStyle: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      dividerColor: divider,
      textTheme: TextTheme(
        displayLarge: AppTextStyles.h1.copyWith(color: onSurface),
        displayMedium: AppTextStyles.h2.copyWith(color: onSurface),
        displaySmall: AppTextStyles.h3.copyWith(color: onSurface),
        headlineMedium: AppTextStyles.h4.copyWith(color: onSurface),
        bodyLarge: AppTextStyles.bodyLarge.copyWith(color: onSurface),
        bodyMedium: AppTextStyles.bodyMedium.copyWith(color: onSurface),
        bodySmall: AppTextStyles.bodySmall.copyWith(color: onSurface),
        labelLarge: AppTextStyles.buttonLarge.copyWith(color: onSurface),
      ),
    );
  }
}
