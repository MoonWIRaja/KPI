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
      } catch (_) {}

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
        body: GlassyCardFrame(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
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
            const MeritBrand(compact: true),
            const SizedBox(height: 28),
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
              validator: (value) =>
                  value == null || !value.trim().contains('@') ? 'Enter a valid email address.' : null,
            ),
            const SizedBox(height: 14),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFB42318).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
              ),
              const SizedBox(height: 12),
            ],
            if (_notice != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF16794B).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_notice!, style: const TextStyle(color: Color(0xFF16794B))),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: _busy ? null : _sendOtp,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
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
}
