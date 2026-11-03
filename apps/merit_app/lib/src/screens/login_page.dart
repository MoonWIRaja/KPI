import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/merit_brand.dart';
import '../widgets/thinking_orbs_loader.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _otp = TextEditingController();

  bool _busy = false;
  bool _codeSent = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
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
        // Fallback if RPC check encounters an issue
      }

      // 2. Request OTP via Supabase Auth (sent through configured Google SMTP)
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

  Future<void> _verifyOtp() async {
    if (!_otpFormKey.currentState!.validate()) return;
    final email = _email.text.trim();
    final token = _otp.text.trim();
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
    } on AuthException {
      if (mounted) setState(() => _error = 'Invalid or expired verification code. Please check your email and try again.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Verification failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _resetEmail() {
    setState(() {
      _codeSent = false;
      _otp.clear();
      _error = null;
      _notice = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(width < 480 ? 16 : 24),
          child: SizedBox(
            width: width < 520 ? double.infinity : 430,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(width < 480 ? 22 : 30),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _codeSent ? _buildOtpForm(context) : _buildEmailForm(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailForm(BuildContext context) => Form(
        key: _emailFormKey,
        child: Column(
          key: const ValueKey('email_form'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const MeritBrand(compact: true),
            const SizedBox(height: 30),
            Text('Sign in', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            const Text(
              'Sign in with your invited email. We will send a one-time verification code (OTP).',
              style: TextStyle(color: Color(0xFF667894)),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email, AutofillHints.username],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _sendOtp(),
              decoration: const InputDecoration(
                labelText: 'Invited email address',
                prefixIcon: Icon(Icons.mail_outline),
                hintText: 'e.g. name@organization.com',
              ),
              validator: (value) => value == null || !value.trim().contains('@') ? 'Enter a valid email address.' : null,
            ),
            const SizedBox(height: 14),
            if (_error != null) _MessageBox(text: _error!, isError: true),
            if (_notice != null) _MessageBox(text: _notice!, isError: false),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _sendOtp,
              icon: _busy
                  ? const ThinkingOrbsLoader(size: 18, label: 'Sending code')
                  : const Icon(Icons.send_rounded),
              label: Text(_busy ? 'Sending code…' : 'Send sign-in code'),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Access is strictly invite-only.\nOnly pre-authorized staff emails will receive a code.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF8896AB)),
              ),
            ),
          ],
        ),
      );

  Widget _buildOtpForm(BuildContext context) => Form(
        key: _otpFormKey,
        child: Column(
          key: const ValueKey('otp_form'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const MeritBrand(compact: true),
            const SizedBox(height: 24),
            Text('Enter verification code', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'A 6-digit one-time code was sent to ${_email.text.trim()}.',
              style: const TextStyle(color: Color(0xFF667894)),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _otp,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _verifyOtp(),
              decoration: const InputDecoration(
                labelText: '6-digit code',
                prefixIcon: Icon(Icons.pin_outlined),
                hintText: '123456',
              ),
              validator: (value) => value == null || value.trim().length < 6 ? 'Enter the full verification code.' : null,
            ),
            const SizedBox(height: 14),
            if (_error != null) _MessageBox(text: _error!, isError: true),
            if (_notice != null) _MessageBox(text: _notice!, isError: false),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _verifyOtp,
              icon: _busy
                  ? const ThinkingOrbsLoader(size: 18, label: 'Verifying code')
                  : const Icon(Icons.check_rounded),
              label: Text(_busy ? 'Verifying…' : 'Verify & Sign In'),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _busy ? null : _resetEmail,
                  child: const Text('Change email'),
                ),
                TextButton(
                  onPressed: _busy ? null : _sendOtp,
                  child: const Text('Resend code'),
                ),
              ],
            ),
          ],
        ),
      );
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFB42318) : const Color(0xFF16794B);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color)),
    );
  }
}
