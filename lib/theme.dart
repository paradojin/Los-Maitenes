import 'package:flutter/material.dart';

class AppTheme {
  // Colores personalizados
  static const Color primaryGreen = Color(0xFF1B5E20); // Verde oscuro
  static const Color primaryGreenLight = Color(0xFF2E7D32); // Verde más claro
  static const Color primaryGreenAccent = Color(0xFF4CAF50); // Verde medio
  static const Color primaryGreenLight2 = Color(0xFFA5D6A7); // Verde claro
  static const Color white = Colors.white;
  static const Color darkText = Color(0xFF1B1B1B);
  static const Color subtleGray = Color(0xFFF5F5F5);
  static const Color borderGray = Color(0xFFEEEEEE);

  // Propuesta B "Operativo y directo": header verde sólido + franjas de estado
  static const Color headerGreen = primaryGreen; // encabezados sólidos
  static const Color statusActive = Color(0xFF2E7D32); // al día
  static const Color statusDebt = Color(0xFFD32F2F); // debe (rojo)
  static const Color statusAbono = Color(0xFFE0A21A); // abono parcial (ámbar)
  static const Color scaffoldBg = Color(0xFFF7F8F6); // fondo app

  // Light Theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryGreen,
      brightness: Brightness.light,
      primary: primaryGreen,
      secondary: primaryGreenLight,
      tertiary: primaryGreenAccent,
      surface: white,
      error: Colors.red,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryGreen,
      foregroundColor: white,
      elevation: 1,
      centerTitle: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryGreen,
        side: const BorderSide(color: primaryGreen, width: 2),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryGreen,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primaryGreen,
      foregroundColor: white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    cardTheme: CardThemeData(
      color: white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.zero,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: subtleGray,
      selectedColor: primaryGreen,
      labelStyle: const TextStyle(
        color: darkText,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      deleteIconColor: darkText,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: const BorderSide(color: borderGray),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: subtleGray,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderGray),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderGray),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      labelStyle: const TextStyle(color: darkText),
      hintStyle: TextStyle(color: darkText.withOpacity(0.5)),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: darkText,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      displayMedium: TextStyle(
        color: darkText,
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
      headlineSmall: TextStyle(
        color: darkText,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: TextStyle(
        color: darkText,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: darkText,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        color: darkText,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: TextStyle(
        color: darkText,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        color: darkText,
        fontSize: 14,
      ),
      bodySmall: TextStyle(
        color: darkText,
        fontSize: 12,
      ),
      labelLarge: TextStyle(
        color: darkText,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: TextStyle(
        color: darkText,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: TextStyle(
        color: darkText,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      tileColor: white,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: borderGray,
      thickness: 1,
      space: 16,
    ),
    scaffoldBackgroundColor: white,
  );
}
