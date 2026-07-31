import 'package:flutter/material.dart';

/// Single source of truth for all PayMuster design tokens.
/// Refer to the PayMuster Design Bible for rationale.

class PMColors {
  // Brand
  static const Color brandPrimaryLight = Color(0xFF0E7C86);
  static const Color brandPrimaryDark = Color(0xFF15D1C2);
  static const Color brandOnPrimaryLight = Colors.white;
  static const Color brandOnPrimaryDark = Color(0xFF0B1117);
  static const Color brandContainerLight = Color(0xFFE0F5F5);
  static const Color brandContainerDark = Color(0xFF0D2E31);
  static const Color brandOnContainerLight = Color(0xFF064B52);
  static const Color brandOnContainerDark = Color(0xFF7EEAE0);

  // Accent
  static const Color accentOrangeLight = Color(0xFFC2610A);
  static const Color accentOrangeDark = Color(0xFFE8720C);
  static const Color accentOnOrange = Colors.white;
  static const Color accentOrangeContainerLight = Color(0xFFFFF0E0);
  static const Color accentOrangeContainerDark = Color(0xFF3D1F04);
  static const Color accentOnOrangeContainerLight = Color(0xFF7A3C06);
  static const Color accentOnOrangeContainerDark = Color(0xFFFFB878);

  // Status
  static const Color statusSuccessLight = Color(0xFF047857);
  static const Color statusSuccessDark = Color(0xFF10B981);
  static const Color statusOnSuccessLight = Colors.white;
  static const Color statusOnSuccessDark = Color(0xFF022C1F);
  static const Color statusSuccessContainerLight = Color(0xFFD4F5E4);
  static const Color statusSuccessContainerDark = Color(0xFF062E1F);

  static const Color statusDangerLight = Color(0xFFB91C1C);
  static const Color statusDangerDark = Color(0xFFEF4444);
  static const Color statusOnDangerLight = Colors.white;
  static const Color statusOnDangerDark = Color(0xFF2C0808);
  static const Color statusDangerContainerLight = Color(0xFFFDE8E8);
  static const Color statusDangerContainerDark = Color(0xFF3B0D0D);

  static const Color statusWarningLight = Color(0xFFD97706);
  static const Color statusWarningDark = Color(0xFFFDBA2D);
  static const Color statusOnWarningLight = Colors.white;
  static const Color statusOnWarningDark = Color(0xFF3D2403);
  static const Color statusWarningContainerLight = Color(0xFFFFF5DC);
  static const Color statusWarningContainerDark = Color(0xFF3D2806);

  // Surface & Background
  static const Color bgPrimaryLight = Color(0xFFFAFAF8);
  static const Color bgPrimaryDark = Color(0xFF0B1117);
  static const Color bgPrimaryAmoled = Colors.black;

  static const Color bgSurfaceLight = Colors.white;
  static const Color bgSurfaceDark = Color(0xFF161B22);
  static const Color bgSurfaceAmoled = Color(0xFF0A0A0A);

  static const Color bgRaisedLight = Color(0xFFF3F1EE);
  static const Color bgRaisedDark = Color(0xFF1D2530);
  static const Color bgRaisedAmoled = Color(0xFF1A1A1A);

  static const Color bgSunkenLight = Color(0xFFEDEBE7);
  static const Color bgSunkenDark = Color(0xFF0A0E13);
  static const Color bgSunkenAmoled = Colors.black;

  static const Color bgOverlayLight = Color(0x66000000); // 40%
  static const Color bgOverlayDark = Color(0x99000000); // 60%
  static const Color bgOverlayAmoled = Color(0xB3000000); // 70%

  // Text
  static const Color textPrimaryLight = Color(0xFF1A1A1A);
  static const Color textPrimaryDark = Color(0xFFF0F0F0);
  
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textSecondaryDark = Color(0xFF8B95A5);
  
  static const Color textTertiaryLight = Color(0xFF9CA3AF);
  static const Color textTertiaryDark = Color(0xFF5C6575);
  
  static const Color textInverseLight = Colors.white;
  static const Color textInverseDark = Color(0xFF0B1117);

  // Border
  static const Color borderDefaultLight = Color(0x14000000); // 8%
  static const Color borderDefaultDark = Color(0x14FFFFFF); // 8%
  
  static const Color borderStrongLight = Color(0x26000000); // 15%
  static const Color borderStrongDark = Color(0x26FFFFFF); // 15%
}

class PMTypography {
  static const String fontFamily = 'Inter';

  // Base TextStyle helper
  static TextStyle _base(double size, FontWeight weight, double height, double tracking) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      height: height / size,
      letterSpacing: tracking,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static final TextStyle displayLarge = _base(32, FontWeight.w700, 40, -0.5);
  static final TextStyle display = _base(28, FontWeight.w700, 34, -0.3);
  static final TextStyle title = _base(22, FontWeight.w700, 28, 0.0);
  static final TextStyle headline = _base(17, FontWeight.w600, 24, 0.0);
  static final TextStyle bodyLarge = _base(16, FontWeight.w400, 24, 0.1);
  static final TextStyle body = _base(15, FontWeight.w400, 22, 0.1);
  static final TextStyle labelLarge = _base(14, FontWeight.w600, 20, 0.2);
  static final TextStyle label = _base(13, FontWeight.w600, 18, 0.2);
  static final TextStyle caption = _base(12, FontWeight.w500, 16, 0.3); // Exception: 500 allowed for caption
  static final TextStyle overline = _base(11, FontWeight.w700, 14, 0.8);
}

class PMSpacing {
  static const double s0 = 0;
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s10 = 40;
  static const double s12 = 48;
}

class PMRadius {
  static const BorderRadius sm = BorderRadius.all(Radius.circular(8));
  static const BorderRadius md = BorderRadius.all(Radius.circular(12));
  static const BorderRadius lg = BorderRadius.all(Radius.circular(16));
  static const BorderRadius full = BorderRadius.all(Radius.circular(9999));
}

class PMElevation {
  static const List<BoxShadow> raisedLight = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 2)), // 6% black
  ];
  static const List<BoxShadow> raisedDark = [
    BoxShadow(color: Color(0x4D000000), blurRadius: 12, offset: Offset(0, 2)), // 30% black
  ];

  static const List<BoxShadow> floatingLight = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 32, offset: Offset(0, 8)), // 12% black
  ];
  static const List<BoxShadow> floatingDark = [
    BoxShadow(color: Color(0x66000000), blurRadius: 32, offset: Offset(0, 8)), // 40% black
  ];
}

class PMMotion {
  // Durations
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 350);
  static const Duration slow = Duration(milliseconds: 600);
  static const Duration pulse = Duration(milliseconds: 800);

  // Easings
  static const Curve standard = Curves.easeOutCubic;
  static const Curve enter = Curves.decelerate;
  static const Curve exit = Curves.easeInCubic;
  static const Curve linear = Curves.linear;
}
