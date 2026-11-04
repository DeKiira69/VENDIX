import 'package:flutter/material.dart';

class AppTheme {
  static const violet = Color(0xFF6C4AB6);
  static const pink = Color(0xFFE9A6C8);
  static const background = Color(0xFFF8F6FA);
  static const dark = Color(0xFF292333);
  static const muted = Color(0xFF81798D);
  static const border = Color(0xFFE8E1ED);
  static const green = Color(0xFF15966B);
  static const orange = Color(0xFFE76F45);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: violet,
        primary: violet,
        secondary: pink,
        surface: Colors.white,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: dark,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: violet, width: 1.5),
        ),
      ),
    );
  }
}
