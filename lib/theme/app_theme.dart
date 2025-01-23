import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors
  static const primaryGreen = Color(0xFF85D45C);
  static const darkGreen = Color(0xFF0D5F3C);
  static const lightGreen = Color(0xFF9ABBAB);
  static const neutralWhite = Color(0xFFFBFBFB);
  static const gray = Color(0xFF7C9C96);
  static const white = Color(0xFFFFFFFF);

  // Gradients
  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [lightGreen, neutralWhite],
  );

  // Shadows
  static const cardShadow = BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 5,
    offset: Offset(0, 2),
  );

  static const buttonShadow = BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 4,
    offset: Offset(0, 2),
  );

  // Border Radius
  static const borderRadius = 8.0;
  static const buttonRadius = 8.0;

  // Typography
  static TextTheme textTheme = TextTheme(
    headlineLarge: GoogleFonts.poppins(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: darkGreen,
    ),
    headlineMedium: GoogleFonts.poppins(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: darkGreen,
    ),
    titleLarge: GoogleFonts.poppins(
      fontSize: 18,
      fontWeight: FontWeight.w500,
      color: darkGreen,
    ),
    bodyLarge: GoogleFonts.poppins(
      fontSize: 16,
      color: Colors.black87,
    ),
    bodyMedium: GoogleFonts.poppins(
      fontSize: 14,
      color: Colors.black87,
    ),
    labelLarge: GoogleFonts.poppins(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Colors.white,
    ),
  );

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: neutralWhite,
    colorScheme: ColorScheme.light(
      primary: primaryGreen,
      secondary: darkGreen,
      surface: white,
      background: neutralWhite,
      onBackground: Colors.black87,
      onSurface: Colors.black87,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    ),
    textTheme: textTheme,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.disabled)) {
            return primaryGreen.withOpacity(0.5);
          }
          if (states.contains(MaterialState.hovered)) {
            return darkGreen;
          }
          return primaryGreen;
        }),
        foregroundColor: MaterialStateProperty.all(Colors.white),
        elevation: MaterialStateProperty.all(2),
        shadowColor: MaterialStateProperty.all(Colors.black26),
        padding: MaterialStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        shape: MaterialStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
        animationDuration: const Duration(milliseconds: 300),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.hovered)) {
            return darkGreen;
          }
          return primaryGreen;
        }),
        side: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.hovered)) {
            return BorderSide(color: darkGreen);
          }
          return BorderSide(color: primaryGreen);
        }),
        padding: MaterialStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        shape: MaterialStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
        animationDuration: const Duration(milliseconds: 300),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide(color: gray.withOpacity(0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide(color: gray.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: primaryGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: Colors.red),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      labelStyle: TextStyle(color: gray),
      hintStyle: TextStyle(color: gray.withOpacity(0.7)),
    ),
    cardTheme: CardTheme(
      color: white,
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    ),
    iconTheme: IconThemeData(
      color: gray,
      size: 24,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: white,
      selectedColor: darkGreen,
      secondarySelectedColor: primaryGreen,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelStyle: TextStyle(color: darkGreen),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    ),
  );
}
