import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/pwa_bridge.dart';
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

  void _openExistingCode() {
    if (!_emailFormKey.currentState!.validate()) return;
    setState(() {
      _error = null;
      _notice = null;
      _codeSent = true;
    });
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
      try {
        final allowed = await Supabase.instance.client.rpc(
          'can_request_otp',
          params: {'email_input': email},
        ) as bool;
        if (!allowed) {
          if (mounted) {
            setState(() {
              _error = 'Email not invited. Contact your administrator.';
              _busy = false;
            });
          }
          return;
        }
      } catch (_) {}

      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
      );

      if (mounted) setState(() => _codeSent = true);
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.message.toLowerCase().contains('rate limit') || e.statusCode == '429') {
        setState(() {
          _codeSent = true;
          _notice = 'A code was recently sent. Enter it below or wait 60s to resend.';
        });
      } else {
        setState(() => _error = 'Email not invited or unavailable.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Connection error. Please try again.');
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
      try {
        await Supabase.instance.client.auth.verifyOTP(
          email: email,
          token: token,
          type: OtpType.email,
        );
      } on AuthException {
        await Supabase.instance.client.auth.verifyOTP(
          email: email,
          token: token,
          type: OtpType.signup,
        );
      }
      return true;
    } on AuthException {
      if (mounted) setState(() => _error = 'Invalid or expired code.');
      return false;
    } catch (_) {
      if (mounted) setState(() => _error = 'Verification failed.');
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
        body: GlassyCardFrame(
          onInstallTap: () => triggerMeritPwaInstall('auto'),
          child: SmoothStepSwitcher(
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
      );

  Widget _buildEmailForm(BuildContext context) => Form(
        key: _emailFormKey,
        child: Column(
          key: const ValueKey('email_form'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const MeritBrand(compact: false),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF3FF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFD6E3FF)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, size: 13, color: Color(0xFF245CEB)),
                      SizedBox(width: 3),
                      Text(
                        'OTP',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF245CEB),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1, color: Color(0xFFEEF2F8)),
            const SizedBox(height: 18),
            Row(
              children: [
                const Text(
                  'Welcome back',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: Color(0xFF141C2E),
                  ),
                ),
                const SizedBox(width: 4),
                const InfoTooltip(
                  message: 'Invite-only access. Only pre-authorized staff and administrator emails will receive a one-time code.',
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Sign in with your invited email to receive a 6-digit verification code.',
              style: TextStyle(color: Color(0xFF667894), fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email, AutofillHints.username],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _sendOtp(),
              decoration: const InputDecoration(
                labelText: 'Work or invited email',
                prefixIcon: Icon(Icons.mail_outline_rounded, size: 20, color: Color(0xFF245CEB)),
                hintText: 'name@organization.com',
              ),
              validator: (value) =>
                  value == null || !value.trim().contains('@') ? 'Enter a valid email.' : null,
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFB42318).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: const TextStyle(color: Color(0xFFB42318), fontSize: 12.5)),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _busy ? null : _sendOtp,
                icon: _busy
                    ? const ThinkingOrbsLoader(size: 18, label: 'Sending')
                    : const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(
                  _busy ? 'Sending code…' : 'Send 6-digit code',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: _busy ? null : _openExistingCode,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.pin_outlined, size: 15),
                label: const Text(
                  'Already have a 6-digit code?',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      );
}
