import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/glassy_otp_view.dart';
import '../widgets/merit_brand.dart';
import '../widgets/thinking_orbs_loader.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailFormKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  bool _busy = false;
  bool _codeSent = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_emailFormKey.currentState!.validate()) return;
    final email = _email.text.trim();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });

    try {
      // 1. Strict invite-only precheck
      try {
        final allowed = await Supabase.instance.client.rpc(
          'can_request_otp',
          params: {'email_input': email},
        ) as bool;
        if (!allowed) {
          if (mounted) {
            setState(() {
              _error = 'Access restricted: This email has not been invited. Please contact your organization administrator.';
              _busy = false;
            });
          }
          return;
        }
      } catch (_) {
        // Fallback if RPC check is unavailable
      }

      // 2. Request OTP via Supabase Auth
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
      );

      if (mounted) {
        setState(() {
          _codeSent = true;
          _notice = 'A 6-digit verification code was sent to $email.';
        });
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _error = e.message.contains('Signups not allowed') || e.message.contains('not found')
            ? 'Access restricted: This email is not registered or invited.'
            : 'Unable to send code: ${e.message}');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to send verification code. Please try again shortly.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _verifyOtp(String token) async {
    final email = _email.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.email,
      );
      return true;
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _error = 'Invalid or expired verification code. (${e.message})');
      }
      return false;
    } catch (_) {
      if (mounted) setState(() => _error = 'Verification failed. Please try again.');
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _resetEmail() {
    setState(() {
      _codeSent = false;
      _error = null;
      _notice = null;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF060911),
        body: Stack(
          children: [
            const MetallicRibbonsBackground(),
            GlassyCardFrame(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _codeSent
                    ? GlassyOtpView(
                        key: const ValueKey('otp_view'),
                        email: _email.text.trim(),
                        busy: _busy,
                        error: _error,
                        notice: _notice,
                        onVerify: _verifyOtp,
                        onResend: _sendOtp,
                        onChangeEmail: _resetEmail,
                      )
                    : _buildEmailForm(context),
              ),
            ),
          ],
        ),
      );

  Widget _buildEmailForm(BuildContext context) => Form(
        key: _emailFormKey,
        child: Column(
          key: const ValueKey('email_form'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Logo
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: const MeritBrand(compact: true),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Sign in',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Sign in with your invited email. We will send a one-time verification code (OTP).',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 22),

            // Email Field styled with dark glass
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email, AutofillHints.username],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _sendOtp(),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Invited email address',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.mail_outline, color: Color(0xFF94A3B8)),
                hintText: 'e.g. name@organization.com',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                fillColor: const Color(0xFF0F172A).withValues(alpha: 0.5),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.8),
                ),
              ),
              validator: (value) =>
                  value == null || !value.trim().contains('@') ? 'Enter a valid email address.' : null,
            ),
            const SizedBox(height: 16),

            if (_error != null) ...[
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
                        _error!,
                        style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (_notice != null) ...[
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
                        _notice!,
                        style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Submit Button
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _sendOtp,
                icon: _busy
                    ? const ThinkingOrbsLoader(size: 18, label: 'Sending code')
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  _busy ? 'Sending code…' : 'Send sign-in code',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.4),
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Center(
              child: Text(
                'Access is strictly invite-only.\nOnly pre-authorized staff emails will receive a code.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.4),
              ),
            ),
          ],
        ),
      );
}
