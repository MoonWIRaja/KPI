import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'thinking_orbs_loader.dart';

/// Compact hover/tap information icon for secondary details.
class InfoTooltip extends StatelessWidget {
  const InfoTooltip({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: message,
        preferBelow: false,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF141C2E),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12, height: 1.35),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF667894)),
        ),
      );
}

/// Framer-Motion style transition switcher (200ms easeOutCubic fade + subtle scale/slide).
class SmoothStepSwitcher extends StatelessWidget {
  const SmoothStepSwitcher({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: Duration(milliseconds: reduceMotion ? 0 : 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (widget, animation) {
        if (reduceMotion) return widget;
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(animation),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.985, end: 1.0).animate(animation),
              child: widget,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// Formal, clean card frame with subtle elevation and entrance motion.
class GlassyCardFrame extends StatelessWidget {
  const GlassyCardFrame({required this.child, this.maxWidth = 400, super.key});

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
            padding: EdgeInsets.all(isMobile ? 22 : 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE3E9F2)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF141C2E).withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Concise, formal OTP verification view with motion polish.
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
      duration: const Duration(milliseconds: 420),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _successAnimController,
      curve: Curves.easeOutBack,
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
        // Top Status Icon
        Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: activeAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: activeAccent.withValues(alpha: 0.28)),
            ),
            child: Icon(Icons.shield_outlined, color: activeAccent, size: 22),
          ),
        ),
        const SizedBox(height: 14),

        // Concise Header + Hover Info
        if (_isVerified) ...[
          Center(
            child: RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                children: [
                  TextSpan(text: 'Verified ', style: TextStyle(color: _headingColor)),
                  TextSpan(text: 'Successfully', style: TextStyle(color: _successColor)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              'Security code confirmed.',
              style: TextStyle(color: _mutedColor, fontSize: 13),
            ),
          ),
        ] else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Verify Code',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _headingColor),
              ),
              const SizedBox(width: 4),
              InfoTooltip(
                message: 'Enter the 6-digit one-time code sent to ${widget.email}. Valid for 10 minutes.',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              widget.email,
              style: const TextStyle(color: _mutedColor, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
        const SizedBox(height: 22),

        // Center PIN Boxes or Checkmark
        if (_isVerified)
          Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: _successColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _successColor.withValues(alpha: 0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 30),
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
                    if (val.length == 6) _submitVerification();
                  },
                  onSubmitted: (_) => _submitVerification(),
                ),
              ),
            ],
          ),
        const SizedBox(height: 18),

        // Compact Error Alert
        if (widget.error != null && !_isVerified) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFB42318).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.error!,
              style: const TextStyle(color: Color(0xFFB42318), fontSize: 12.5),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Primary Action Button
        if (_isVerified)
          FilledButton.icon(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: _successColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.verified_user_outlined, size: 18),
            label: const Text('Verified & Secured', style: TextStyle(fontWeight: FontWeight.w600)),
          )
        else
          FilledButton.icon(
            onPressed: widget.busy || _rawOtp.text.length < 6 ? null : _submitVerification,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: widget.busy
                ? const ThinkingOrbsLoader(size: 18, label: 'Verifying')
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(
              widget.busy ? 'Verifying…' : 'Verify & Continue',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),

        // Footer Row: Change Email + Countdown Timer
        if (!_isVerified) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: widget.busy ? null : widget.onChangeEmail,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Change email', style: TextStyle(fontSize: 12.5)),
              ),
              if (_secondsRemaining > 0)
                Text(
                  'Resend in 00:${_secondsRemaining.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Color(0xFFD97706),
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                )
              else
                TextButton(
                  onPressed: widget.busy ? null : _handleResend,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Resend code',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                  ),
                ),
            ],
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
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            width: 45,
            height: 52,
            decoration: BoxDecoration(
              color: isActive ? Colors.white : const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive
                    ? _primaryColor
                    : digit.isNotEmpty
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFFD9E1EC),
                width: isActive ? 1.8 : 1.0,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: _primaryColor.withValues(alpha: 0.12),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: digit.isNotEmpty
                  ? Text(
                      digit,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: _headingColor,
                      ),
                    )
                  : isActive
                      ? Container(
                          width: 2,
                          height: 18,
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
