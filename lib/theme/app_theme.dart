import 'package:flutter/material.dart';

class AppTheme {
  static const _cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(14)),
  );

  static final dark = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.black,
    colorScheme: const ColorScheme.dark(
      surface: Color(0xFF161618),
      onSurface: Color(0xFFF5F5F7),
      primary: Color(0xFF0A84FF),
      secondary: Color(0xFF5E5CE6),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: const CardThemeData(
      shape: _cardShape,
      color: Color(0xFF1C1C1E),
      elevation: 0,
    ),
    dividerTheme: DividerThemeData(
      color: Colors.white.withOpacity(0.08),
      thickness: 1,
    ),
    useMaterial3: true,
  );

  static final light = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF2F2F7),
    colorScheme: const ColorScheme.light(
      surface: Colors.white,
      onSurface: Color(0xFF1D1D1F),
      primary: Color(0xFF007AFF),
      secondary: Color(0xFF5856D6),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: Color(0xFF1D1D1F)),
      titleTextStyle: TextStyle(
        color: Color(0xFF1D1D1F),
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: const CardThemeData(
      shape: _cardShape,
      color: Colors.white,
      elevation: 0,
    ),
    dividerTheme: DividerThemeData(
      color: Colors.black.withOpacity(0.08),
      thickness: 1,
    ),
    useMaterial3: true,
  );
}
