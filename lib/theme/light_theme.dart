import 'package:flutter/material.dart';
import '../core/constants/app_text_styles.dart';

/// Thème clair moderne et élégant
class LightTheme {
  LightTheme._();

  // Couleurs du guide de style Light Mode
  static const Color primary = Color(0xFF1A2E53); // Deep Blue
  static const Color secondary = Color(0xFFFF6F61); // Vibrant Coral
  static const Color background = Color(0xFFF7F9FC); // Light background
  static const Color surface = Color(0xFFFFFFFF); // White
  static const Color textPrimary = Color(0xFF1D1D1D); // Dark text
  static const Color textSecondary = Color(0xFF555555); // Subtext
  static const Color iconColor = Color(0xFF555555); // Dark grey icons
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  static ThemeData get theme {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: Colors.white,
      error: error,
      onError: Colors.white,
      background: background,
      onBackground: textPrimary,
      surface: surface,
      onSurface: textPrimary,
      surfaceVariant: const Color(0xFFF3F4F6),
      outline: const Color(0xFFE5E7EB),
      shadow: Colors.black.withOpacity(0.08),
      inverseSurface: primary,
      inversePrimary: Colors.white,
      tertiary: secondary,
      onTertiary: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.h3.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: iconColor),
        actionsIconTheme: const IconThemeData(color: iconColor),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        margin: EdgeInsets.zero,
        shadowColor: Colors.black.withOpacity(0.08),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: textSecondary,
        ),
        labelStyle: AppTextStyles.bodyMedium.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: primary, width: 1.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
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
          foregroundColor: primary,
          textStyle: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: secondary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      dividerColor: const Color(0xFFE5E7EB),
      textTheme: TextTheme(
        displayLarge: AppTextStyles.h1.copyWith(color: textPrimary),
        displayMedium: AppTextStyles.h2.copyWith(color: textPrimary),
        displaySmall: AppTextStyles.h3.copyWith(color: textPrimary),
        headlineMedium: AppTextStyles.h4.copyWith(color: textPrimary),
        bodyLarge: AppTextStyles.bodyLarge.copyWith(color: textPrimary),
        bodyMedium: AppTextStyles.bodyMedium.copyWith(color: textPrimary),
        bodySmall: AppTextStyles.bodySmall.copyWith(color: textSecondary),
        labelLarge: AppTextStyles.buttonLarge.copyWith(color: textPrimary),
      ),
    );
  }
}

