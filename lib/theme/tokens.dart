import 'package:flutter/material.dart';

/// Design tokens — Hermes (dark dev-tool, indigo accent).
/// Source : `hermes-design/project/tokens.jsx` (Geist + Geist Mono).
class HermesTokens {
  HermesTokens._();

  // ── couleurs ─────────────────────────────────────────────
  static const Color accent = Color(0xFF6366F1);
  static const Color accentDim = Color(0xFF4F46E5);
  static const Color accentSoft = Color(0x1F6366F1); // 12 %
  static const Color accentRing = Color(0x596366F1); // 35 %

  static const Color bg = Color(0xFF0B0C0F); // code blocks (deepest)
  static const Color surface = Color(0xFF15171D); // app bg (lifted un cran)
  static const Color surface1 = Color(0xFF1C1F25); // cards / composer
  static const Color surface2 = Color(0xFF22262E); // hover / raised
  static const Color surface3 = Color(0xFF2A2E37); // pressed

  static const Color border = Color(0x0FFFFFFF); // 6 %
  static const Color borderStrong = Color(0x1AFFFFFF); // 10 %
  static const Color borderFocus = Color(0x736366F1); // 45 %

  static const Color text = Color(0xF5FFFFFF); // 96 %
  static const Color textDim = Color(0xA8FFFFFF); // 66 %
  static const Color textMuted = Color(0x6BFFFFFF); // 42 %
  static const Color textFaint = Color(0x3DFFFFFF); // 24 %

  static const Color success = Color(0xFF3FB950);
  static const Color warn = Color(0xFFD29922);
  static const Color error = Color(0xFFF85149);
  static const Color successSoft = Color(0x1F3FB950);
  static const Color warnSoft = Color(0x1FD29922);
  static const Color errorSoft = Color(0x1FF85149);

  // ── espacements (4 / 8 / 12 / 16 / 24 / 32 / 48 / 64) ───
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 24;
  static const double s6 = 32;
  static const double s7 = 48;
  static const double s8 = 64;

  // ── radii ────────────────────────────────────────────────
  static const double rSm = 6;
  static const double rMd = 10;
  static const double rLg = 14;
  static const double rXl = 20;
  static const double rFull = 999;

  // ── durées ───────────────────────────────────────────────
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration medium = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 280);
  static const Duration pulse = Duration(milliseconds: 1000);
}
