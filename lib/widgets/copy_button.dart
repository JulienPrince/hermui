import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Bouton "copier" avec animation de feedback : icône bascule en check vert,
/// pulse léger pendant ~1.6 s, puis revient à l'état normal.
class CopyButton extends StatefulWidget {
  const CopyButton({
    super.key,
    required this.text,
    this.size = 26,
    this.iconSize = 13,
  });

  final String text;
  final double size;
  final double iconSize;

  @override
  State<CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<CopyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  bool _copied = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    _ctrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _copy,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, anim) {
              return ScaleTransition(
                scale: Tween<double>(begin: 0.7, end: 1.0).animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                ),
                child: FadeTransition(opacity: anim, child: child),
              );
            },
            child: _copied
                ? Icon(
                    Icons.check_rounded,
                    key: const ValueKey('check'),
                    size: widget.iconSize,
                    color: HermesTokens.success,
                  )
                : Icon(
                    Icons.copy_rounded,
                    key: const ValueKey('copy'),
                    size: widget.iconSize,
                    color: HermesTokens.textMuted,
                  ),
          ),
        ),
      ),
    );
  }
}
