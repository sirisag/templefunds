import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepOrange,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
    // To use a custom font like Sarabun, you need to add it to your project's
    // pubspec.yaml file and place the font files in an 'assets/fonts' folder.
    // fontFamily: 'Sarabun',
    appBarTheme: AppBarTheme(
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.1),
      backgroundColor: Colors.grey[50],
      foregroundColor: Colors.black87,
      titleTextStyle: const TextStyle(
        // fontFamily: 'Sarabun',
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    ),
    cardTheme: CardThemeData(
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
    outlinedButtonTheme: OutlinedButtonThemeData(
       style: OutlinedButton.styleFrom(
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
      fillColor: Colors.grey.shade100.withOpacity(0.5),
    ),
  );
}