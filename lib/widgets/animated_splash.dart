import 'package:flutter/material.dart';

import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import 'hermes_logo.dart';

/// Splash Flutter animé — prend le relais du splash natif (image statique)
/// avec une apparition douce du logo + pulse léger du glow.
class AnimatedSplash extends StatefulWidget {
  const AnimatedSplash({super.key});

  @override
  State<AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends State<AnimatedSplash>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _pulse;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = CurvedAnimation(
      parent: _entrance,
      curve: Curves.easeOutCubic,
    ).drive(Tween(begin: 0.84, end: 1.0));
    _opacity = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _entrance.forward();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _entrance.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HermesTokens.surface,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: Listenable.merge([_entrance, _pulse]),
                  builder: (_, _) {
                    final glow = 16 + _pulse.value * 16;
                    return Opacity(
                      opacity: _opacity.value,
                      child: Transform.scale(
                        scale: _scale.value,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: HermesTokens.accent.withValues(
                                  alpha: 0.18 + _pulse.value * 0.18,
                                ),
                                blurRadius: glow,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const HermesLogo(size: 72, glow: false),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: HermesTokens.s5),
                FadeTransition(
                  opacity: _opacity,
                  child: Text(
                    'hermui',
                    style: HermesText.title(color: HermesTokens.textDim)
                        .copyWith(letterSpacing: -0.3),
                  ),
                ),
                const SizedBox(height: 6),
                FadeTransition(
                  opacity: _opacity,
                  child: Text(
                    'connexion à ton agent',
                    style: HermesText.caption(color: HermesTokens.textFaint),
                  ),
                ),
              ],
            ),
          ),
          // Crédit en bas — fade-in plus tardif que le logo principal pour un
          // séquençage propre (logo puis credit).
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _entrance,
                    curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
                  ),
                  child: Center(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'powered by ',
                            style: HermesText.caption(
                              color: HermesTokens.textFaint,
                            ),
                          ),
                          TextSpan(
                            text: 'J.Prince',
                            style: HermesText.caption(
                              color: HermesTokens.textMuted,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
