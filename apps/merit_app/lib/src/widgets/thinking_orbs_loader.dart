import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A small Flutter-native adaptation of the dotted Thinking Orbs loader.
/// Inspired by https://github.com/Jakubantalik/thinking-orbs (MIT).
class ThinkingOrbsLoader extends StatefulWidget {
  const ThinkingOrbsLoader({this.size = 34, this.label = 'Loading', super.key});

  final double size;
  final String label;

  @override
  State<ThinkingOrbsLoader> createState() => _ThinkingOrbsLoaderState();
}

class _ThinkingOrbsLoaderState extends State<ThinkingOrbsLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: widget.label,
      liveRegion: true,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _OrbPainter(
                phase: reduceMotion || TickerMode.of(context) == false ? 0 : _controller.value,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  const _OrbPainter({required this.phase, required this.color});

  final double phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * .34;
    final dotRadius = size.shortestSide * .052;
    final paint = Paint()..color = color;
    for (var i = 0; i < 8; i++) {
      final angle = (i / 8 * math.pi * 2) - phase * math.pi * 2;
      final depth = .32 + (i / 7 * .68);
      final scale = .76 + depth * .24;
      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      paint.color = color.withValues(alpha: .24 + depth * .68);
      canvas.drawCircle(point, dotRadius * scale, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.color != color;
}
