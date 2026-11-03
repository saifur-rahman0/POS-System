import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF0F766E); // Teal 700
  static const Color secondaryColor = Color(0xFF0D9488); // Teal 600
  static const Color backgroundColor = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceColor = Colors.white;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardTheme(
        color: surfaceColor,
        elevation: 1,
        margin: EdgeInsets.all(8),
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}

