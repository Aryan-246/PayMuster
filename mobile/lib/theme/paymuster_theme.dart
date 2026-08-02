import 'package:flutter/material.dart';
import 'paymuster_tokens.dart';

class PayMusterTheme {
  static ThemeData lightTheme() => _buildTheme(
        brightness: Brightness.light,
        background: PMColors.bgPrimaryLight,
        surface: PMColors.bgSurfaceLight,
        surfaceRaised: PMColors.bgRaisedLight,
        primary: PMColors.brandPrimaryLight,
        primaryStrong: PMColors.brandPrimaryDark,
        textPrimary: PMColors.textPrimaryLight,
        textSecondary: PMColors.textSecondaryLight,
        border: PMColors.borderDefaultLight,
        error: PMColors.statusDangerLight,
      );

  static ThemeData darkTheme() => _buildTheme(
        brightness: Brightness.dark,
        background: PMColors.bgPrimaryDark,
        surface: PMColors.bgSurfaceDark,
        surfaceRaised: PMColors.bgRaisedDark,
        primary: PMColors.brandPrimaryDark,
        primaryStrong: PMColors.brandPrimaryLight,
        textPrimary: PMColors.textPrimaryDark,
        textSecondary: PMColors.textSecondaryDark,
        border: PMColors.borderDefaultDark,
        error: PMColors.statusDangerDark,
      );

  static ThemeData amoledTheme() => _buildTheme(
        brightness: Brightness.dark,
        background: PMColors.bgPrimaryAmoled,
        surface: PMColors.bgSurfaceAmoled,
        surfaceRaised: PMColors.bgRaisedAmoled,
        primary: PMColors.brandPrimaryDark,
        primaryStrong: PMColors.brandPrimaryLight,
        textPrimary: PMColors.textPrimaryDark,
        textSecondary: PMColors.textSecondaryDark,
        border: PMColors.borderDefaultDark, // Same as dark for borders usually
        error: PMColors.statusDangerDark,
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceRaised,
    required Color primary,
    required Color primaryStrong,
    required Color textPrimary,
    required Color textSecondary,
    required Color border,
    required Color error,
  }) {
    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      fontFamily: PMTypography.fontFamily,
    );

    final colorScheme = brightness == Brightness.dark
        ? ColorScheme.dark(
            primary: primary,
            onPrimary: PMColors.brandOnPrimaryDark,
            secondary: primaryStrong,
            surface: surface,
            surfaceContainerHighest: surfaceRaised,
            onSurface: textPrimary,
            onSurfaceVariant: textSecondary,
            error: error,
          )
        : ColorScheme.light(
            primary: primary,
            onPrimary: PMColors.brandOnPrimaryLight,
            secondary: primaryStrong,
            surface: surface,
            surfaceContainerHighest: surfaceRaised,
            onSurface: textPrimary,
            onSurfaceVariant: textSecondary,
            error: error,
          );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: PMTypography.title.copyWith(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0, // Elevations are managed via BoxDecoration in PayMuster
        shape: RoundedRectangleBorder(
          borderRadius: PMRadius.md,
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: PMSpacing.s4,
          vertical: PMSpacing.s4,
        ),
        border: OutlineInputBorder(
          borderRadius: PMRadius.sm,
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: PMRadius.sm,
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: PMRadius.sm,
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: PMRadius.sm,
          borderSide: BorderSide(color: error, width: 2),
        ),
        labelStyle: PMTypography.body.copyWith(color: textSecondary),
        hintStyle: PMTypography.body.copyWith(color: textSecondary),
      ),
      textTheme: base.textTheme.copyWith(
        displayLarge: PMTypography.displayLarge.copyWith(color: textPrimary),
        displayMedium: PMTypography.display.copyWith(color: textPrimary),
        titleLarge: PMTypography.title.copyWith(color: textPrimary),
        headlineMedium: PMTypography.headline.copyWith(color: textPrimary),
        bodyLarge: PMTypography.bodyLarge.copyWith(color: textPrimary),
        bodyMedium: PMTypography.body.copyWith(color: textPrimary),
        labelLarge: PMTypography.labelLarge.copyWith(color: textPrimary),
        labelMedium: PMTypography.label.copyWith(color: textPrimary),
        labelSmall: PMTypography.caption.copyWith(color: textSecondary),
      ),
      iconTheme: IconThemeData(color: textSecondary, size: 24),
      dividerColor: border,
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
