import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'thinking_orbs_loader.dart';

/// Full background with fluid metallic gold/bronze/slate ribbons
class MetallicRibbonsBackground extends StatelessWidget {
  const MetallicRibbonsBackground({super.key});

  @override
  Widget build(BuildContext context) => const Positioned.fill(
        child: CustomPaint(
          painter: _MetallicRibbonsPainter(),
        ),
      );
}

/// Cyber-glass card container with corner chamfer bracket accents and frosted glass blur
class GlassyCardFrame extends StatelessWidget {
  const GlassyCardFrame({required this.child, this.maxWidth = 420, super.key});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 480;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1E293B).withValues(alpha: 0.55),
                      const Color(0xFF0F172A).withValues(alpha: 0.65),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 36,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: CustomPaint(
                        painter: _CornerAccentsPainter(),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(isMobile ? 24 : 32),
                      child: child,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glassy OTP Verification widget inspired by modern cyber-glass aesthetics.
class GlassyOtpView extends StatefulWidget {
  const GlassyOtpView({
    required this.email,
    required this.onVerify,
    required this.onResend,
    required this.onChangeEmail,
    this.isInitialSetup = false,
    this.error,
    this.notice,
    this.busy = false,
    super.key,
  });

  final String email;
  final Future<bool> Function(String otp) onVerify;
  final Future<void> Function() onResend;
  final VoidCallback onChangeEmail;
  final bool isInitialSetup;
  final String? error;
  final String? notice;
  final bool busy;

  @override
  State<GlassyOtpView> createState() => _GlassyOtpViewState();
}

class _GlassyOtpViewState extends State<GlassyOtpView> with SingleTickerProviderStateMixin {
  final TextEditingController _rawOtp = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _countdownTimer;
  int _secondsRemaining = 60;
  bool _isVerified = false;
  late final AnimationController _successAnimController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _successAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _successAnimController,
      curve: Curves.elasticOut,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _rawOtp.dispose();
    _focusNode.dispose();
    _successAnimController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _secondsRemaining = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _handleResend() async {
    if (_secondsRemaining > 0 || widget.busy) return;
    _rawOtp.clear();
    _startCountdown();
    await widget.onResend();
    if (mounted) _focusNode.requestFocus();
  }

  Future<void> _submitVerification() async {
    final code = _rawOtp.text.trim();
    if (code.length < 6 || widget.busy || _isVerified) return;

    final success = await widget.onVerify(code);
    if (success && mounted) {
      setState(() => _isVerified = true);
      _successAnimController.forward();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Shield Badge
          Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.45),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.25),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: Color(0xFF10B981),
                size: 26,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header Title & Subtitle
          if (_isVerified) ...[
            Center(
              child: RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  children: [
                    TextSpan(text: 'Verified ', style: TextStyle(color: Colors.white)),
                    TextSpan(text: 'Successfully', style: TextStyle(color: Color(0xFF10B981))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                'Your security verification code has been confirmed.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ),
          ] else ...[
            Center(
              child: Text(
                widget.isInitialSetup
                    ? 'Enter setup verification code'
                    : 'Enter verification code',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'A 6-digit one-time code was sent to ${widget.email}.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 28),

          // Center Interactive Area
          if (_isVerified)
            // Big Glowing Checkmark Box
            Center(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFF10B981),
                      width: 2.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.5),
                        blurRadius: 22,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
            )
          else
            // 6 Individual Glassy PIN Boxes with Hidden Raw Input
            Stack(
              alignment: Alignment.center,
              children: [
                _buildPinBoxes(context),
                Opacity(
                  opacity: 0.0,
                  child: TextField(
                    controller: _rawOtp,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: (val) {
                      setState(() {});
                      if (val.length == 6) {
                        _submitVerification();
                      }
                    },
                    onSubmitted: (_) => _submitVerification(),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),

          // Alerts
          if (widget.error != null && !_isVerified) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFF87171), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.error!,
                      style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (widget.notice != null && !_isVerified) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Color(0xFF34D399), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.notice!,
                      style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Resend Countdown Timer
          if (!_isVerified) ...[
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Didn't receive the code? ",
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  ),
                  if (_secondsRemaining > 0)
                    Text(
                      'Resend in 00:${_secondsRemaining.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: Color(0xFFFBBF24),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    )
                  else
                    InkWell(
                      onTap: widget.busy ? null : _handleResend,
                      child: const Text(
                        'Resend code',
                        style: TextStyle(
                          color: Color(0xFF38BDF8),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ] else ...[
            const SizedBox(height: 12),
          ],

          // Action Button
          if (_isVerified)
            Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_user_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Verified & Secured',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: widget.busy || _rawOtp.text.length < 6 ? null : _submitVerification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF10B981).withValues(alpha: 0.35),
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: widget.busy
                    ? const ThinkingOrbsLoader(size: 20, label: 'Verifying code')
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield_outlined, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Verify & Continue',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ],
                      ),
              ),
            ),

          // Change Email Option
          if (!_isVerified) ...[
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                onPressed: widget.busy ? null : widget.onChangeEmail,
                child: const Text(
                  'Change email address',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      );

  Widget _buildPinBoxes(BuildContext context) {
    final text = _rawOtp.text;
    final isFocused = _focusNode.hasFocus;

    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(6, (index) {
          final digit = index < text.length ? text[index] : '';
          final isActive = isFocused && index == text.length.clamp(0, 5);

          return Container(
            width: 48,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? const Color(0xFF10B981)
                    : digit.isNotEmpty
                        ? Colors.white.withValues(alpha: 0.45)
                        : Colors.white.withValues(alpha: 0.16),
                width: isActive ? 1.8 : 1.1,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: digit.isNotEmpty
                  ? Text(
                      digit,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFamily: 'monospace',
                      ),
                    )
                  : isActive
                      ? Container(
                          width: 2,
                          height: 22,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        )
                      : const SizedBox.shrink(),
            ),
          );
        }),
      ),
    );
  }
}

class _MetallicRibbonsPainter extends CustomPainter {
  const _MetallicRibbonsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Midnight obsidian background
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF060911), Color(0xFF0C1322), Color(0xFF05070C)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. Ambient radial lighting glows
    final goldGlow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.85, -0.6),
        radius: 0.85,
        colors: [
          const Color(0xFFD4AF37).withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), goldGlow);

    final cyanGlow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.85, 0.75),
        radius: 0.9,
        colors: [
          const Color(0xFF1E3A8A).withValues(alpha: 0.22),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), cyanGlow);

    // 3. Flowing metallic ribbons
    final ribbon1 = Path()
      ..moveTo(0, size.height * 0.12)
      ..cubicTo(size.width * 0.45, size.height * 0.02, size.width * 0.75, size.height * 0.42, size.width, size.height * 0.32)
      ..lineTo(size.width, size.height * 0.45)
      ..cubicTo(size.width * 0.68, size.height * 0.58, size.width * 0.32, size.height * 0.22, 0, size.height * 0.26)
      ..close();

    final ribbon1Paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFE5A93C),
          Color(0xFF9E6E24),
          Color(0xFF261906),
          Color(0x000B132B),
        ],
        stops: [0.0, 0.38, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(ribbon1, ribbon1Paint);

    final ribbon2 = Path()
      ..moveTo(size.width * 0.15, 0)
      ..cubicTo(size.width * 0.35, size.height * 0.28, size.width * 0.8, size.height * 0.48, size.width * 1.1, size.height * 0.85)
      ..lineTo(size.width * 1.05, size.height * 0.92)
      ..cubicTo(size.width * 0.72, size.height * 0.54, size.width * 0.28, size.height * 0.34, size.width * 0.08, 0)
      ..close();

    final ribbon2Paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          Color(0x99D4AF37),
          Color(0x558A6421),
          Color(0x181A1A24),
          Color(0x00000000),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(ribbon2, ribbon2Paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CornerAccentsPainter extends CustomPainter {
  const _CornerAccentsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    final fillPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;

    // Top-left chamfer accent
    final tl = Path()
      ..moveTo(8, 28)
      ..lineTo(8, 16)
      ..quadraticBezierTo(8, 8, 16, 8)
      ..lineTo(28, 8)
      ..lineTo(8, 28)
      ..close();
    canvas.drawPath(tl, fillPaint);
    canvas.drawPath(tl, strokePaint);

    // Bottom-right chamfer accent
    final br = Path()
      ..moveTo(size.width - 8, size.height - 28)
      ..lineTo(size.width - 8, size.height - 16)
      ..quadraticBezierTo(size.width - 8, size.height - 8, size.width - 16, size.height - 8)
      ..lineTo(size.width - 28, size.height - 8)
      ..lineTo(size.width - 8, size.height - 28)
      ..close();
    canvas.drawPath(br, fillPaint);
    canvas.drawPath(br, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
