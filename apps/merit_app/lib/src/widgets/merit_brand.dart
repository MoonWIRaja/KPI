import 'package:flutter/material.dart';

/// Tactile 3D spatial surface card with top specular highlight, 3D bottom bevel lip,
/// layered ambient/key depth shadows, and optional Framer-Motion hover/press physics.
class Surface3DCard extends StatefulWidget {
  const Surface3DCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 14,
    this.interactive = false,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool interactive;
  final VoidCallback? onTap;

  @override
  State<Surface3DCard> createState() => _Surface3DCardState();
}

class _Surface3DCardState extends State<Surface3DCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final activeInteractive = widget.interactive || widget.onTap != null;
    final translateY = !activeInteractive
        ? 0.0
        : _pressed
            ? 1.5
            : _hovered
                ? -2.5
                : 0.0;
    final scale = !activeInteractive
        ? 1.0
        : _pressed
            ? 0.992
            : 1.0;

    return MouseRegion(
      cursor: activeInteractive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: activeInteractive ? (_) => setState(() => _hovered = true) : null,
      onExit: activeInteractive
          ? (_) => setState(() {
                _hovered = false;
                _pressed = false;
              })
          : null,
      child: GestureDetector(
        onTapDown: activeInteractive ? (_) => setState(() => _pressed = true) : null,
        onTapUp: activeInteractive ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: activeInteractive ? () => setState(() => _pressed = false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: Duration(milliseconds: reduceMotion ? 0 : 160),
          curve: Curves.easeOutCubic,
          scale: scale,
          child: AnimatedContainer(
            duration: Duration(milliseconds: reduceMotion ? 0 : 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0.0, translateY, 0.0),
            padding: widget.padding,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFFAFCFF),
                ],
              ),
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: _hovered && activeInteractive ? const Color(0xFFB8CCF0) : const Color(0xFFDCE5F2),
                width: 1.2,
              ),
              boxShadow: [
                // 3D Tactile Bottom Bevel Lip Shadow (compatible with uniform BorderRadius)
                BoxShadow(
                  color: _hovered && activeInteractive ? const Color(0xFF9EB8E8) : const Color(0xFFCBD6E6),
                  blurRadius: 0,
                  offset: Offset(0, _pressed ? 1.5 : 3.0),
                ),
                BoxShadow(
                  color: const Color(0xFF141C2E).withValues(alpha: _hovered && activeInteractive ? 0.08 : 0.05),
                  blurRadius: _hovered && activeInteractive ? 22 : 16,
                  offset: Offset(0, _hovered && activeInteractive ? 10 : 6),
                ),
                BoxShadow(
                  color: const Color(0xFF245CEB).withValues(alpha: _hovered && activeInteractive ? 0.07 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class MeritBrand extends StatelessWidget {
  const MeritBrand({this.compact = false, this.title, super.key});

  final bool compact;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 36.0 : 42.0;
    final displayTitle = title?.trim().isNotEmpty == true ? title!.trim() : 'Merit Tracker';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: displayTitle,
          child: SizedBox(
            width: size,
            height: size,
            child: const CustomPaint(painter: _MeritLogoPainter()),
          ),
        ),
        SizedBox(width: compact ? 10 : 12),
        Text(
          displayTitle,
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
