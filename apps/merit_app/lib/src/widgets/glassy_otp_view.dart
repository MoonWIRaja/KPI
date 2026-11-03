import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'thinking_orbs_loader.dart';

/// Light glassy card container matching the Merit Tracker system palette (#F7F9FC / White / #141C2E)
/// with the corner chamfer accents from the reference design.
class GlassyCardFrame extends StatelessWidget {
  const GlassyCardFrame({required this.child, this.maxWidth = 430, super.key});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 480;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE3E9F2), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF141C2E).withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: _CornerAccentsPainter()),
                ),
                Padding(
                  padding: EdgeInsets.all(isMobile ? 22 : 30),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// OTP Verification view using the original Merit Tracker light color palette
/// with the reference layout and verification animation.
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

  static const _primaryColor = Color(0xFF245CEB);
  static const _successColor = Color(0xFF16794B);
  static const _headingColor = Color(0xFF141C2E);
  static const _mutedColor = Color(0xFF667894);

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _successAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
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
  Widget build(BuildContext context) {
    final activeAccent = _isVerified ? _successColor : _primaryColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Shield Badge
        Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: activeAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: activeAccent.withValues(alpha: 0.35),
                width: 1.4,
              ),
            ),
            child: Icon(
              Icons.shield_outlined,
              color: activeAccent,
              size: 25,
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
                  TextSpan(text: 'Verified ', style: TextStyle(color: _headingColor)),
                  TextSpan(text: 'Successfully', style: TextStyle(color: _successColor)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'Your security verification code has been confirmed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _mutedColor, fontSize: 13),
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
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: _headingColor,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'A 6-digit one-time code was sent to ${widget.email}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _mutedColor, fontSize: 13),
            ),
          ),
        ],
        const SizedBox(height: 26),

        // Center Interactive Area
        if (_isVerified)
          Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _successColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _successColor, width: 2.2),
                  boxShadow: [
                    BoxShadow(
                      color: _successColor.withValues(alpha: 0.25),
                      blurRadius: 18,
                      spreadRadius: 1,
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
        const SizedBox(height: 22),

        // Alerts
        if (widget.error != null && !_isVerified) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFB42318).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.error!,
              style: const TextStyle(color: Color(0xFFB42318), fontSize: 13),
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (widget.notice != null && !_isVerified) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _successColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.notice!,
              style: const TextStyle(color: _successColor, fontSize: 13),
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
                  style: TextStyle(color: _mutedColor, fontSize: 13),
                ),
                if (_secondsRemaining > 0)
                  Text(
                    'Resend in 00:${_secondsRemaining.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: Color(0xFFD97706),
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
                        color: _primaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ] else ...[
          const SizedBox(height: 10),
        ],

        // Action Button
        if (_isVerified)
          FilledButton.icon(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: _successColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.verified_user_outlined, size: 18),
            label: const Text('Verified & Secured', style: TextStyle(fontWeight: FontWeight.w700)),
          )
        else
          FilledButton.icon(
            onPressed: widget.busy || _rawOtp.text.length < 6 ? null : _submitVerification,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: widget.busy
                ? const ThinkingOrbsLoader(size: 18, label: 'Verifying code')
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(
              widget.busy
                  ? 'Verifying…'
                  : widget.isInitialSetup
                      ? 'Verify & Continue Setup'
                      : 'Verify & Sign In',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),

        // Change Email Option
        if (!_isVerified) ...[
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: widget.busy ? null : widget.onChangeEmail,
              child: const Text('Change email'),
            ),
          ),
        ],
      ],
    );
  }

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

          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 46,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: isActive
                    ? _primaryColor
                    : digit.isNotEmpty
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFFD9E1EC),
                width: isActive ? 1.8 : 1.1,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: _primaryColor.withValues(alpha: 0.15),
                        blurRadius: 8,
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
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _headingColor,
                      ),
                    )
                  : isActive
                      ? Container(
                          width: 2,
                          height: 20,
                          decoration: BoxDecoration(
                            color: _primaryColor,
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

class _CornerAccentsPainter extends CustomPainter {
  const _CornerAccentsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = const Color(0xFFD9E1EC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    final fillPaint = Paint()
      ..color = const Color(0xFFF7F9FC)
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
