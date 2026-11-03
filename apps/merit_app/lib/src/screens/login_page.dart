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
      if (mounted) {
        setState(() => _error = e.message.toLowerCase().contains('rate limit')
            ? 'Rate limit reached. Please wait 60s.'
            : 'Email not invited or unavailable.');
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
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: GlassyCardFrame(
          child: SmoothStepSwitcher(
            child: _codeSent
                ? GlassyOtpView(
                    key: const ValueKey('otp_view'),
                    email: _email.text.trim(),
                    busy: _busy,
                    error: _error,
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
            const SizedBox(height: 22),
            Row(
              children: [
                Text('Sign in', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(width: 4),
                const InfoTooltip(
                  message: 'Invite-only access. Only pre-authorized staff and administrator emails will receive a one-time code.',
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Enter your invited email for a 6-digit code.',
              style: TextStyle(color: Color(0xFF667894), fontSize: 13),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email, AutofillHints.username],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _sendOtp(),
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                hintText: 'name@organization.com',
              ),
              validator: (value) =>
                  value == null || !value.trim().contains('@') ? 'Enter a valid email.' : null,
            ),
            const SizedBox(height: 14),
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
            FilledButton.icon(
              onPressed: _busy ? null : _sendOtp,
              icon: _busy
                  ? const ThinkingOrbsLoader(size: 18, label: 'Sending')
                  : const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                _busy ? 'Sending…' : 'Send sign-in code',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}
