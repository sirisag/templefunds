import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart';

class AppTheme {
  /// Generates a ThemeData object based on a given seed color.
  static ThemeData getTheme(Color seedColor, double fontScale) {
    // Define base font sizes to be scaled
    const double baseBodyLarge = 18;
    const double baseBodyMedium = 15;
    const double baseTitleLarge = 24;
    const double baseTitleMedium = 18;
    const double baseLabelLarge = 15;
    const double baseAppBarTitle = 20;

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      useMaterial3: true,
      // To use a custom font like Sarabun, you need to add it to your project's
      // pubspec.yaml file and place the font files in an 'assets/fonts' folder.
      fontFamily: 'Sarabun',
      textTheme: TextTheme(
        // For body text like in ListTiles or paragraphs
        bodyLarge: TextStyle(fontSize: baseBodyLarge * fontScale),
        bodyMedium: TextStyle(fontSize: baseBodyMedium * fontScale),

        // For titles on cards or sections
        titleLarge: TextStyle(fontSize: baseTitleLarge * fontScale),
        titleMedium: TextStyle(fontSize: baseTitleMedium * fontScale),

        // For buttons and other labels
        labelLarge: TextStyle(fontSize: baseLabelLarge * fontScale),
      ).apply(
        fontFamily: 'Sarabun',
        bodyColor: Colors.black87, // Ensure default text color is consistent
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: seedColor.withOpacity(0.1),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.black87,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Sarabun',
          fontSize: baseAppBarTitle * fontScale,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withOpacity(0.60),
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.grey.shade300,
            width: 0.5,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30), // Pill shape
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: const Color.fromARGB(255, 250, 250, 250).withOpacity(0.5),
      ),
    );
  }
}
