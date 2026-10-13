import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract class AppTheme {
  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.forest500,
      onPrimary: AppColors.parchment50,
      primaryContainer: AppColors.forest100,
      onPrimaryContainer: AppColors.forest700,
      secondary: AppColors.clay400,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.clay100,
      onSecondaryContainer: AppColors.clay600,
      tertiary: AppColors.wheat400,
      onTertiary: AppColors.ink600,
      tertiaryContainer: AppColors.wheat100,
      onTertiaryContainer: AppColors.wheat600,
      error: AppColors.clay500,
      onError: Colors.white,
      errorContainer: AppColors.clay50,
      onErrorContainer: AppColors.clay600,
      surface: AppColors.parchment50,
      onSurface: AppColors.ink500,
      surfaceContainerHighest: AppColors.parchment100,
      onSurfaceVariant: AppColors.ink300,
      outline: AppColors.parchment300,
      outlineVariant: AppColors.parchment200,
      shadow: Color(0x1A000000),
      scrim: Color(0x80000000),
      inverseSurface: AppColors.ink600,
      onInverseSurface: AppColors.parchment50,
      inversePrimary: AppColors.forest200,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.parchment50,
      textTheme: GoogleFonts.atkinsonHyperlegibleNextTextTheme().copyWith(
        displayLarge: GoogleFonts.literata(fontSize: 48, fontWeight: FontWeight.w300),
        displayMedium: GoogleFonts.literata(fontSize: 36, fontWeight: FontWeight.w300),
        displaySmall: GoogleFonts.literata(fontSize: 28, fontWeight: FontWeight.w400),
        headlineLarge: GoogleFonts.literata(fontSize: 24, fontWeight: FontWeight.w500),
        headlineMedium: GoogleFonts.literata(fontSize: 20, fontWeight: FontWeight.w500),
        headlineSmall: GoogleFonts.literata(fontSize: 18, fontWeight: FontWeight.w500),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.parchment300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.parchment300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.ink300),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 11, letterSpacing: 1.2, color: AppColors.ink300),
        hintStyle: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 14, color: AppColors.ink200),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ink600,
          foregroundColor: AppColors.parchment50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 13, letterSpacing: 2, fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink500,
          side: const BorderSide(color: AppColors.parchment300),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 12, letterSpacing: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
          side: BorderSide(color: AppColors.parchment200),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.parchment200,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.forest100,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.forest500, size: 22);
          }
          return const IconThemeData(color: AppColors.ink200, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.atkinsonHyperlegibleNext(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.forest500 : AppColors.ink300,
          );
        }),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.black12,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink600,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black12,
        titleTextStyle: GoogleFonts.literata(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: AppColors.ink600,
        ),
        centerTitle: false,
      ),
    );
  }

  static ThemeData dark() {
    // Dark theme mirrors light but with inverted surfaces
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.forest200,
      onPrimary: AppColors.forest700,
      primaryContainer: AppColors.forest600,
      onPrimaryContainer: AppColors.forest100,
      secondary: AppColors.clay200,
      onSecondary: AppColors.clay600,
      secondaryContainer: AppColors.clay500,
      onSecondaryContainer: AppColors.clay100,
      tertiary: AppColors.wheat300,
      onTertiary: AppColors.wheat600,
      tertiaryContainer: AppColors.wheat500,
      onTertiaryContainer: AppColors.wheat100,
      error: AppColors.clay300,
      onError: AppColors.clay600,
      errorContainer: AppColors.clay500,
      onErrorContainer: AppColors.clay100,
      surface: AppColors.ink600,
      onSurface: AppColors.parchment100,
      surfaceContainerHighest: AppColors.ink500,
      onSurfaceVariant: AppColors.ink100,
      outline: AppColors.ink400,
      outlineVariant: AppColors.ink500,
      shadow: Color(0x33000000),
      scrim: Color(0x80000000),
      inverseSurface: AppColors.parchment100,
      onInverseSurface: AppColors.ink600,
      inversePrimary: AppColors.forest500,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.ink600,
    );
  }
}
