import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  final Color _primarySeedColor = const Color(0xFF6B35FF);

  // Define a common TextTheme
  TextTheme get _appTextTheme => TextTheme(
        displayLarge: GoogleFonts.pacifico(
            fontSize: 57, fontWeight: FontWeight.bold, color: Colors.white),
        titleLarge: GoogleFonts.poppins(
            fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        bodyMedium: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
        headlineSmall: GoogleFonts.poppins(
            fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white),
      );

  // Light Theme
  ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primarySeedColor,
          brightness: Brightness.light,
        ),
        textTheme: _appTextTheme.apply(
          bodyColor: Colors.black,
          displayColor: Colors.black,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: _primarySeedColor,
          foregroundColor: Colors.white,
          titleTextStyle: GoogleFonts.poppins(
              fontSize: 24, fontWeight: FontWeight.bold),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: _primarySeedColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      );

  // Dark Theme
  ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primarySeedColor,
          brightness: Brightness.dark,
          background: const Color(0xFF1A1A1A),
        ),
        textTheme: _appTextTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[900],
          foregroundColor: Colors.white,
          titleTextStyle: GoogleFonts.poppins(
              fontSize: 24, fontWeight: FontWeight.bold),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFF9E7BFF), // Corrected Color
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      );
}
