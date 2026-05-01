import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Mini barre des 14 derniers runs d'un job.
/// La dernière barre est pleinement opaque, les autres à 0.6.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.bars,
    this.barWidth = 2.5,
    this.gap = 2,
    this.maxHeight = 20,
  });

  /// Liste de paires `(hauteur en px, couleur)`.
  final List<SparkBar> bars;
  final double barWidth;
  final double gap;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: maxHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < bars.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Container(
              width: barWidth,
              height: bars[i].height,
              decoration: BoxDecoration(
                color: bars[i].color.withValues(
                  alpha: i == bars.length - 1 ? 1.0 : 0.6,
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SparkBar {
  const SparkBar({required this.height, required this.color});
  final double height;
  final Color color;
}

/// Génère 14 barres déterministes pour un job, basé sur son id et son statut.
List<SparkBar> sparkBarsForJob({
  required String jobId,
  required String? status,
}) {
  final s = status?.toLowerCase();
  final isFailed = s == 'failed' || s == 'failure' || s == 'error';
  final isPaused = s == 'paused' || s == 'disabled';

  return List.generate(14, (i) {
    final h = 4.0 + ((i * 73 + jobId.length * 41) % 11);
    Color color;
    if (isPaused && i >= 10) {
      color = HermesTokens.textFaint;
    } else if (isFailed && i == 13) {
      color = HermesTokens.error;
    } else {
      color = HermesTokens.success;
    }
    return SparkBar(height: h, color: color);
  });
}
