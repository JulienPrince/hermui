import 'package:flutter/material.dart';

import '../theme/tokens.dart';

enum JobStatusKind { active, paused, failed, running, idle }

JobStatusKind statusKindFrom(String? raw) {
  switch (raw?.toLowerCase()) {
    case 'scheduled':
    case 'active':
    case 'ok':
    case 'success':
    case 'enabled':
      return JobStatusKind.active;
    case 'failed':
    case 'failure':
    case 'error':
      return JobStatusKind.failed;
    case 'paused':
    case 'disabled':
      return JobStatusKind.paused;
    case 'running':
    case 'in_progress':
      return JobStatusKind.running;
    default:
      return JobStatusKind.idle;
  }
}

class StatusDot extends StatefulWidget {
  const StatusDot({
    super.key,
    required this.kind,
    this.pulse = false,
    this.size = 8,
  });

  final JobStatusKind kind;
  final bool pulse;
  final double size;

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.pulse) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && !_ctrl.isAnimating) _ctrl.repeat();
    if (!widget.pulse && _ctrl.isAnimating) _ctrl.stop();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _color {
    switch (widget.kind) {
      case JobStatusKind.active:
        return HermesTokens.success;
      case JobStatusKind.paused:
        return HermesTokens.warn; // orange — distingue net de "désactivé"
      case JobStatusKind.failed:
        return HermesTokens.error;
      case JobStatusKind.running:
        return HermesTokens.accent;
      case JobStatusKind.idle:
        return HermesTokens.textFaint;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return SizedBox(
      width: widget.size + 6,
      height: widget.size + 6,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.pulse)
              FadeTransition(
                opacity: Tween(begin: 0.25, end: 1.0).animate(
                  CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
                ),
                child: Container(
                  width: widget.size + 6,
                  height: widget.size + 6,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }
}
