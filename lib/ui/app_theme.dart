import 'package:flutter/material.dart';

class AppTheme {
  // Dark Theme Palette
  static const Color darkBg = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkCard = Color(0xFF182234);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkHover = Color(0xFF273549);

  // Light Theme Palette
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightHover = Color(0xFFE2E8F0);

  // Accents
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color danger = Color(0xFFEF4444); // Rose
  static const Color purple = Color(0xFF8B5CF6);

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accentCyan,
        surface: darkSurface,
        error: danger,
        onPrimary: Colors.white,
        onSurface: Color(0xFFF1F5F9),
      ),
      cardTheme: const CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: darkBorder, width: 1),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF131D30),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      fontFamily: 'sans-serif',
    );
  }

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      primaryColor: primary,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: accentCyan,
        surface: lightSurface,
        error: danger,
        onPrimary: Colors.white,
        onSurface: Color(0xFF0F172A),
      ),
      cardTheme: const CardThemeData(
        color: lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: lightBorder, width: 1),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      fontFamily: 'sans-serif',
    );
  }
}
