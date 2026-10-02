import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';class AppTheme {
  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
    final soraTextTheme = GoogleFonts.soraTextTheme(ThemeData.dark().textTheme);

    // 2026 Unicorn Health Theme Palette
    const bgDark = Color(0xFF050510);
    const surfaceDark = Color(0xFF0A0C18);
    const accentCyan = Color(0xFF00FFFF);
    const accentPink = Color(0xFFFF00FF);
    const accentViolet = Color(0xFF8A2BE2);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      colorScheme: const ColorScheme.dark(
        background: bgDark,
        surface: surfaceDark,
        primary: accentCyan,
        secondary: accentViolet,
        tertiary: accentPink,
        error: Color(0xFFFF3366),
        onPrimary: bgDark,
        onBackground: Colors.white,
        onSurface: Colors.white,
      ),
      fontFamily: GoogleFonts.outfit().fontFamily,
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: -1,
        ),
        displayMedium: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
        bodyLarge: GoogleFonts.outfit(
          fontSize: 16,
          color: Colors.white70,
        ),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 14,
          color: Colors.white70,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.sora(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: Colors.white,
          letterSpacing: 1.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withOpacity(0.03), // Glassmorphism base
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentCyan,
          foregroundColor: bgDark,
          elevation: 10,
          shadowColor: accentCyan.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.sora(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}
