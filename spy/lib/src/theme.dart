import 'package:flutter/material.dart';

const saathiGreen = Color(0xFF176B52);
const saathiTeal = Color(0xFF0E8A78);
const saathiMint = Color(0xFFE7F5EF);
const saathiInk = Color(0xFF17211E);
const saathiCream = Color(0xFFF8FAF7);
const saathiNavy = Color(0xFF16233F);
const saathiBodyGrey = Color(0xFF5A6B7C);
const saathiEmergency = Color(0xFFB3261E);

const saathiInkSoft = Color(0xFF44554F);
const saathiLine = Color(0xFFDDE5E1);
const saathiEmergencyDeep = Color(0xFF8C1D18);
const saathiEmergencyTint = Color(0xFFFCEEEC);
const saathiBlue = Color(0xFF275D8C);
const saathiAmber = Color(0xFFF4B740);

const double kStaffMinTarget = 48.0;
const double kHospitalWorkingWatermarkOpacity = 0.025;
const double kHospitalWorkingWatermarkSpacing = 120.0;

ThemeData buildSaathiTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: saathiGreen,
    brightness: Brightness.light,
    surface: saathiCream,
    error: saathiEmergency,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: saathiCream,
    appBarTheme: const AppBarTheme(
      backgroundColor: saathiCream,
      foregroundColor: saathiInk,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: saathiInk,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w900,
        color: saathiInk,
        height: 1.15,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w900,
        color: saathiInk,
        height: 1.2,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: saathiInk,
        height: 1.25,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: saathiInk,
        height: 1.45,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: saathiInkSoft,
        height: 1.45,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: saathiLine),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: saathiLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: saathiGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: saathiEmergency),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        // Size.fromHeight sets the width to infinity, which breaks buttons
        // placed in constrained areas such as AppBar.actions.
        minimumSize: const Size(64, kStaffMinTarget),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        // Keep a finite minimum width so outlined buttons can be laid out in
        // toolbars, dialogs, and rows.
        minimumSize: const Size(64, kStaffMinTarget),
        side: const BorderSide(color: saathiLine),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
