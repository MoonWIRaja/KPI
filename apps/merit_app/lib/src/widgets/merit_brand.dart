import 'package:flutter/material.dart';

class MeritBrand extends StatelessWidget {
  const MeritBrand({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 36.0 : 42.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'Merit Tracker',
          child: SizedBox(
            width: size,
            height: size,
            child: const CustomPaint(painter: _MeritLogoPainter()),
          ),
        ),
        SizedBox(width: compact ? 10 : 12),
        Text(
          'Merit Tracker',
          style: TextStyle(
            fontSize: compact ? 17 : 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: const Color(0xFF1E3A8A),
          ),
        ),
      ],
    );
  }
}

class _MeritLogoPainter extends CustomPainter {
  const _MeritLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 64.0;
    final rect = Offset.zero & size;

    // 1. Blue gradient squircle background (matches favicon.svg #bg)
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(16 * s)),
      bgPaint,
    );

    // 2. Left ribbon tail
    final leftRibbon = Path()
      ..moveTo(23 * s, 36 * s)
      ..lineTo(19 * s, 52 * s)
      ..lineTo(27 * s, 47 * s)
      ..lineTo(31 * s, 52 * s)
      ..lineTo(29 * s, 38 * s)
      ..close();
    canvas.drawPath(leftRibbon, Paint()..color = const Color(0xFFFFA000));

    // 3. Right ribbon tail
    final rightRibbon = Path()
      ..moveTo(41 * s, 36 * s)
      ..lineTo(45 * s, 52 * s)
      ..lineTo(37 * s, 47 * s)
      ..lineTo(33 * s, 52 * s)
      ..lineTo(35 * s, 38 * s)
      ..close();
    canvas.drawPath(rightRibbon, Paint()..color = const Color(0xFFFF8F00));

    // 4. Gold medal circle
    final medalRect = Rect.fromCircle(center: Offset(32 * s, 25 * s), radius: 14 * s);
    final goldPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFE082), Color(0xFFFFB300)],
      ).createShader(medalRect);
    canvas.drawCircle(Offset(32 * s, 25 * s), 14 * s, goldPaint);

    // Inner ring
    final ringPaint = Paint()
      ..color = const Color(0xFFFFF8E1).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * s;
    canvas.drawCircle(Offset(32 * s, 25 * s), 10.5 * s, ringPaint);

    // 5. Center white star
    final star = Path()
      ..moveTo(32 * s, 17.5 * s)
      ..lineTo(34.1 * s, 22 * s)
      ..lineTo(39 * s, 22.6 * s)
      ..lineTo(35.4 * s, 25.9 * s)
      ..lineTo(36.4 * s, 30.7 * s)
      ..lineTo(32 * s, 28.3 * s)
      ..lineTo(27.6 * s, 30.7 * s)
      ..lineTo(28.6 * s, 25.9 * s)
      ..lineTo(25 * s, 22.6 * s)
      ..lineTo(29.9 * s, 22 * s)
      ..close();
    canvas.drawPath(star, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
