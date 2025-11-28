import 'package:flutter/material.dart';
import '../core/constants/app_text_styles.dart';
import '../core/constants/app_colors.dart';

/// Thème sombre (adapté du thème existant)
class DarkTheme {
  DarkTheme._();

  static ThemeData get theme {
    final Color background = AppColors.night;
    final Color surface = AppColors.nightSurface;
    final Color onBackground = Colors.white;
    final Color onSurface = Colors.white;
    final Color divider = Colors.white12;

    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
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
      shadow: Colors.black.withOpacity(0.6),
      surfaceVariant: AppColors.nightSecondary,
      inverseSurface: AppColors.primaryDark,
      inversePrimary: AppColors.primaryLight,
      tertiary: AppColors.accent,
      onTertiary: AppColors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
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
        shadowColor: Colors.black.withOpacity(0.4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.nightSecondary,
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: Colors.white60,
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: AppTextStyles.buttonLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          textStyle: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
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

