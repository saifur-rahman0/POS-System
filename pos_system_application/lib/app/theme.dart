import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Sidebar & Primary Dark
  static const Color sidebarBg = Color(0xFF0F172A);       // Slate 900
  static const Color sidebarHover = Color(0xFF1E293B);    // Slate 800
  static const Color sidebarActive = Color(0xFF14B8A6);   // Teal 500 pill bg

  // Accent Colors
  static const Color accentTeal = Color(0xFF14B8A6);      // Primary accent
  static const Color accentPurple = Color(0xFF8B5CF6);    // Revenue/charts
  static const Color accentBlue = Color(0xFF3B82F6);      // Inventory
  static const Color accentAmber = Color(0xFFF59E0B);     // Profit/warnings
  static const Color accentRose = Color(0xFFF43F5E);      // Alerts/refunds
  static const Color accentGreen = Color(0xFF10B981);     // Positive/stock

  // Surfaces
  static const Color pageBg = Color(0xFFF8FAFC);          // Slate 50
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE2E8F0);      // Slate 200

  // Text
  static const Color textPrimary = Color(0xFF0F172A);     // Slate 900
  static const Color textSecondary = Color(0xFF64748B);   // Slate 500
  static const Color textMuted = Color(0xFF94A3B8);       // Slate 400

  // Header bar
  static const Color headerBg = Color(0xFF0F172A);        // matches sidebar
}

class AppTheme {
  // Keep for backward compat
  static const Color primaryColor = AppColors.accentTeal;
  static const Color secondaryColor = Color(0xFF0D9488);
  static const Color backgroundColor = AppColors.pageBg;
  static const Color surfaceColor = AppColors.cardWhite;

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      fontFamilyFallback: const [
        'Nirmala UI', 'Segoe UI', 'Kalpurush', 'Noto Sans Bengali', 'Arial', 'sans-serif',
      ],
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accentTeal,
        primary: AppColors.accentTeal,
        secondary: AppColors.accentPurple,
        surface: AppColors.cardWhite,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.pageBg,
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textSecondary,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textMuted,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.headerBg,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardWhite,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.cardBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accentTeal, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        labelStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
        hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accentTeal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentTeal,
          side: const BorderSide(color: AppColors.accentTeal),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.accentTeal,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.accentTeal,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: AppColors.cardBorder,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFF0F766E),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1E293B),
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.cardBorder, thickness: 1, space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentTextStyle: GoogleFonts.inter(fontSize: 13, color: Colors.white),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}
