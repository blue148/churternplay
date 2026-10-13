import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract class AppTextStyles {
  // Display — Literata (serif)
  static TextStyle display(
          {double size = 32, FontWeight weight = FontWeight.w300, Color? color}) =>
      GoogleFonts.literata(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.ink600,
        letterSpacing: 0.5,
      );

  // Body — Atkinson Hyperlegible Next (sans-serif)
  static TextStyle body(
          {double size = 14, FontWeight weight = FontWeight.w400, Color? color}) =>
      GoogleFonts.atkinsonHyperlegibleNext(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.ink500,
      );

  // Mono — DM Mono
  static TextStyle mono(
          {double size = 12, FontWeight weight = FontWeight.w400, Color? color}) =>
      GoogleFonts.dmMono(
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
