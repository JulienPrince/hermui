import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Échelle typographique — Geist UI + Geist Mono.
class HermesText {
  HermesText._();

  static TextStyle _base({
    required double size,
    required FontWeight weight,
    required double height,
    double track = 0,
    Color? color,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: track * size,
      color: color ?? HermesTokens.text,
    );
  }

  static TextStyle display({Color? color}) => _base(
        size: 32,
        weight: FontWeight.w600,
        height: 1.15,
        track: -0.02,
        color: color,
      );

  static TextStyle title({Color? color}) => _base(
        size: 20,
        weight: FontWeight.w600,
        height: 1.25,
        track: -0.015,
        color: color,
      );

  static TextStyle section({Color? color}) => _base(
        size: 15,
        weight: FontWeight.w600,
        height: 1.35,
        track: -0.01,
        color: color,
      );

  static TextStyle body({Color? color}) => _base(
        size: 15,
        weight: FontWeight.w400,
        height: 1.45,
        track: -0.005,
        color: color,
      );

  static TextStyle bodySm({Color? color}) => _base(
        size: 13,
        weight: FontWeight.w400,
        height: 1.45,
        color: color,
      );

  static TextStyle caption({Color? color}) => _base(
        size: 12,
        weight: FontWeight.w500,
        height: 1.35,
        color: color,
      );

  static TextStyle eyebrow({Color? color}) => _base(
        size: 11,
        weight: FontWeight.w600,
        height: 1.2,
        track: 0.06,
        color: color,
      );

  static TextStyle mono({double size = 13, FontWeight weight = FontWeight.w400, Color? color}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      height: 1.55,
      color: color ?? HermesTokens.text,
    );
  }
}
