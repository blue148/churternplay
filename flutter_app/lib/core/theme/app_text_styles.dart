import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The app's three font families, bundled as assets (see pubspec.yaml). This
/// is the only place family names are spelled out: serif = Literata,
/// sans-serif = Atkinson Hyperlegible (Next), mono = DM Mono.
abstract class AppFonts {
  static const serifFamily = 'Literata';
  static const sansFamily = 'AtkinsonHyperlegibleNext';
  static const monoFamily = 'DMMono';

  static TextStyle serif({
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    Color? color,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
  }) =>
      TextStyle(
        fontFamily: serifFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        decoration: decoration,
      );

  static TextStyle sans({
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    Color? color,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
  }) =>
      TextStyle(
        fontFamily: sansFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        decoration: decoration,
      );

  static TextStyle mono({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      TextStyle(
        fontFamily: monoFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
}

abstract class AppTextStyles {
  // Display — Literata (serif)
  static TextStyle display(
          {double size = 32, FontWeight weight = FontWeight.w300, Color? color}) =>
      AppFonts.serif(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.ink600,
        letterSpacing: 0.5,
      );

  // Body — Atkinson Hyperlegible Next (sans-serif)
  static TextStyle body(
          {double size = 14, FontWeight weight = FontWeight.w400, Color? color}) =>
      AppFonts.sans(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.ink500,
      );

  // Mono — DM Mono
  static TextStyle mono(
          {double size = 12, FontWeight weight = FontWeight.w400, Color? color}) =>
      AppFonts.mono(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.ink400,
      );

  // Convenience shorthands
  static TextStyle label({Color? color}) => body(
        size: 11,
        weight: FontWeight.w500,
        color: color ?? AppColors.ink300,
      ).copyWith(letterSpacing: 1.2);

  static TextStyle caption({Color? color}) => body(
        size: 10,
        color: color ?? AppColors.ink200,
      );
}
