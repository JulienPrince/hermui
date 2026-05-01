import 'package:flutter/material.dart';

import '../theme/tokens.dart';

const _glyph = '⚡'; // emoji unique source de vérité (= app icon, splash)

/// Carré indigo avec ⚡ — logo de l'app.
class HermesLogo extends StatelessWidget {
  const HermesLogo({
    super.key,
    this.size = 28,
    this.glow = true,
  });

  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final radius = size * (8 / 28);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: HermesTokens.accent,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: glow
            ? const [
                BoxShadow(
                  color: HermesTokens.accentSoft,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
        border: Border.all(color: const Color(0x0FFFFFFF), width: 1),
      ),
      child: Center(
        child: Text(
          _glyph,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: size * (16 / 28),
            // Désactive l'ascender padding pour centrer optiquement l'emoji.
            height: 1.0,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Variante outline (fond surface1, ⚡ indigo) pour l'empty state du chat.
class HermesLogoOutline extends StatelessWidget {
  const HermesLogoOutline({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: HermesTokens.surface1,
        border: Border.all(color: HermesTokens.border, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          _glyph,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: size * (22 / 44),
            height: 1.0,
            color: HermesTokens.accent,
          ),
        ),
      ),
    );
  }
}
