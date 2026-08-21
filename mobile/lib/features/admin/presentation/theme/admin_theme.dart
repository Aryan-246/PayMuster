import 'package:flutter/material.dart';
import 'admin_tokens.dart';

class AdminTheme {
  static ThemeData get theme {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: AdminTypography.fontFamily,
      scaffoldBackgroundColor: AdminColors.background,
    );

    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: AdminColors.primary,
        onPrimary: AdminColors.onPrimary,
        primaryContainer: AdminColors.primaryContainer,
        onPrimaryContainer: AdminColors.onPrimaryContainer,
        secondary: AdminColors.secondary,
        onSecondary: AdminColors.onSecondary,
        secondaryContainer: AdminColors.secondaryContainer,
        onSecondaryContainer: AdminColors.onSecondaryContainer,
        surface: AdminColors.surface,
        surfaceContainerLowest: AdminColors.surfaceContainerLowest,
        surfaceContainerLow: AdminColors.surfaceContainerLow,
        surfaceContainer: AdminColors.surfaceContainer,
        surfaceContainerHigh: AdminColors.surfaceContainerHigh,
        surfaceContainerHighest: AdminColors.surfaceContainerHighest,
        onSurface: AdminColors.onSurface,
        onSurfaceVariant: AdminColors.onSurfaceVariant,
        outline: AdminColors.outline,
        outlineVariant: AdminColors.outlineVariant,
        error: AdminColors.error,
        onError: AdminColors.onError,
        errorContainer: AdminColors.errorContainer,
        onErrorContainer: AdminColors.onErrorContainer,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AdminColors.surface,
        foregroundColor: AdminColors.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AdminTypography.titleMd.copyWith(
          color: AdminColors.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: AdminColors.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AdminRadius.xl,
          side: const BorderSide(color: AdminColors.glassBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AdminColors.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AdminSpacing.md,
          vertical: AdminSpacing.compact,
        ),
        border: OutlineInputBorder(
          borderRadius: AdminRadius.md,
          borderSide: const BorderSide(color: AdminColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AdminRadius.md,
          borderSide: const BorderSide(color: AdminColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AdminRadius.md,
          borderSide: const BorderSide(color: AdminColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AdminRadius.md,
          borderSide: const BorderSide(color: AdminColors.error, width: 1),
        ),
        labelStyle: AdminTypography.bodyMd.copyWith(
          color: AdminColors.onSurfaceVariant,
        ),
        hintStyle: AdminTypography.bodyMd.copyWith(
          color: AdminColors.onSurfaceMuted,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AdminColors.primary,
          foregroundColor: AdminColors.onPrimary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: AdminRadius.md),
          textStyle: AdminTypography.titleSm,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AdminColors.primary,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: AdminColors.outline),
          shape: RoundedRectangleBorder(borderRadius: AdminRadius.md),
          textStyle: AdminTypography.titleSm,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AdminColors.primary,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: AdminRadius.md),
          textStyle: AdminTypography.titleSm,
        ),
      ),
      textTheme: base.textTheme.copyWith(
        displayLarge: AdminTypography.displayLg.copyWith(
          color: AdminColors.onSurface,
        ),
        headlineLarge: AdminTypography.headlineLg.copyWith(
          color: AdminColors.onSurface,
        ),
        headlineMedium: AdminTypography.headlineLgMobile.copyWith(
          color: AdminColors.onSurface,
        ),
        titleMedium: AdminTypography.titleMd.copyWith(
          color: AdminColors.onSurface,
        ),
        bodyMedium: AdminTypography.bodyMd.copyWith(
          color: AdminColors.onSurface,
        ),
        labelSmall: AdminTypography.labelSm.copyWith(
          color: AdminColors.onSurfaceVariant,
        ),
      ),
      iconTheme: const IconThemeData(
        color: AdminColors.onSurfaceVariant,
        size: 20,
      ),
      dividerColor: AdminColors.glassBorder,
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AdminColors.primary,
        linearTrackColor: AdminColors.surfaceContainerHigh,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AdminColors.surfaceContainerHighest,
        contentTextStyle: AdminTypography.bodyMd.copyWith(
          color: AdminColors.onSurface,
        ),
        actionTextColor: AdminColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AdminRadius.md),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AdminColors.surfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }
}
