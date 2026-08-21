import 'package:flutter/material.dart';

/// Single source of truth for the Super Admin visual system.
///
/// These admin-scoped tokens implement the canonical PayMuster design language
/// without changing the theme used by worker and owner routes.
class AdminColors {
  // Brand
  static const Color primary = Color(0xFF15D1C2);
  static const Color primaryContainer = Color(0xFF15D1C2);
  static const Color onPrimary = Color(0xFF062F2D);
  static const Color onPrimaryContainer = Color(0xFFB9FFF8);
  static const Color inversePrimary = Color(0xFF0E7C86);

  // Supporting accents
  static const Color secondary = Color(0xFF3B82F6);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFF1E3A5F);
  static const Color onSecondaryContainer = Color(0xFFBFDBFE);

  static const Color tertiary = Color(0xFFFDBA2D);
  static const Color onTertiary = Color(0xFF3D2B00);
  static const Color tertiaryContainer = Color(0xFF4A360B);
  static const Color onTertiaryContainer = Color(0xFFFFE3A3);

  // Semantic
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFFDBA2D);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  static const Color neutral = Color(0xFF8B95A5);

  static const Color error = danger;
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFF4C171A);
  static const Color onErrorContainer = Color(0xFFFFC7C7);

  // Compatibility aliases used by existing admin screens.
  static const Color successEmerald = success;
  static const Color dangerCrimson = danger;
  static const Color accentAzure = info;

  // Surfaces and backgrounds
  static const Color background = Color(0xFF0B1117);
  static const Color onBackground = Color(0xFFFFFFFF);

  static const Color surface = Color(0xFF0B1117);
  static const Color surfaceDim = Color(0xFF080D12);
  static const Color surfaceBright = Color(0xFF26313E);
  static const Color surfaceContainerLowest = Color(0xFF080D12);
  static const Color surfaceContainerLow = Color(0xFF111820);
  static const Color surfaceContainer = Color(0xFF161B22);
  static const Color surfaceContainerHigh = Color(0xFF1D2530);
  static const Color surfaceContainerHighest = Color(0xFF26313E);

  static const Color onSurface = Color(0xFFFFFFFF);
  static const Color onSurfaceVariant = Color(0xFF8B95A5);
  static const Color onSurfaceMuted = Color(0xFF6B7280);
  static const Color inverseSurface = Color(0xFFF3F4F6);
  static const Color inverseOnSurface = Color(0xFF111827);

  static const Color outline = Color(0xFF53606F);
  static const Color outlineVariant = Color(0x1FFFFFFF);
  static const Color surfaceTint = primary;

  static const Color glassBorder = Color(0x14FFFFFF);
  static const Color strongBorder = Color(0x1FFFFFFF);
}

class AdminTypography {
  static const String fontFamily = 'Inter';
  static const String monoFamily = 'JetBrains Mono';

  static TextStyle _base(
    String family,
    double size,
    FontWeight weight,
    double lineHeight,
  ) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: weight,
      height: lineHeight / size,
      letterSpacing: 0,
    );
  }

  static final TextStyle displayLg = _base(fontFamily, 40, FontWeight.w700, 48);
  static final TextStyle headlineLg = _base(
    fontFamily,
    28,
    FontWeight.w700,
    36,
  );
  static final TextStyle headlineLgMobile = _base(
    fontFamily,
    24,
    FontWeight.w700,
    32,
  );
  static final TextStyle headlineSm = _base(
    fontFamily,
    20,
    FontWeight.w600,
    28,
  );
  static final TextStyle titleMd = _base(fontFamily, 16, FontWeight.w600, 24);
  static final TextStyle titleSm = _base(fontFamily, 14, FontWeight.w600, 20);
  static final TextStyle bodyMd = _base(fontFamily, 14, FontWeight.w400, 20);
  static final TextStyle bodySm = _base(fontFamily, 12, FontWeight.w400, 18);
  static final TextStyle labelSm = _base(fontFamily, 11, FontWeight.w600, 16);
  static final TextStyle labelMono = _base(monoFamily, 12, FontWeight.w500, 16);
  static final TextStyle statValue = _base(fontFamily, 28, FontWeight.w700, 34);
}

class AdminSpacing {
  static const double base = 4;
  static const double xs = 4;
  static const double sm = 8;
  static const double compact = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;
  static const double gutterMobile = 16;
  static const double gutterDesktop = 24;
}

class AdminRadius {
  static const BorderRadius sm = BorderRadius.all(Radius.circular(4));
  static const BorderRadius base = BorderRadius.all(Radius.circular(6));
  static const BorderRadius md = BorderRadius.all(Radius.circular(8));
  static const BorderRadius lg = BorderRadius.all(Radius.circular(8));
  static const BorderRadius xl = BorderRadius.all(Radius.circular(12));
  static const BorderRadius full = BorderRadius.all(Radius.circular(9999));
}
