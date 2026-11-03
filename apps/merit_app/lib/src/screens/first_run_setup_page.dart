import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/merit_brand.dart';
import '../widgets/thinking_orbs_loader.dart';

class FirstRunSetupPage extends StatefulWidget {
  const FirstRunSetupPage({super.key});

  @override
  State<FirstRunSetupPage> createState() => _FirstRunSetupPageState();
}

class _FirstRunSetupPageState extends State<FirstRunSetupPage> {
  final _emailForm = GlobalKey<FormState>();
  final _otpForm = GlobalKey<FormState>();
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

  Future<void> _sendSetupOtp() async {
    if (!_emailForm.currentState!.validate()) return;
    final email = _email.text.trim();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });

    try {
      // Check if email matches expected initial owner
      try {
        final allowed = await Supabase.instance.client.rpc(
          'can_request_otp',
          params: {'email_input': email},
        ) as bool;
        if (!allowed) {
          if (mounted) {
            setState(() {
              _error = 'This email is not authorized for initial Owner setup. Please verify the designated operator email.';
              _busy = false;
            });
          }
          return;
        }
      } catch (_) {}

      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
      );

      if (mounted) {
        setState(() {
          _codeSent = true;
          _notice = 'A 6-digit setup verification code was sent to $email.';
        });
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = 'Unable to send code: ${e.message}');
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to connect right now. Check the configuration and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifySetupOtp() async {
    if (!_otpForm.currentState!.validate()) return;
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
      if (mounted) setState(() => _error = 'Invalid or expired setup code. Please check your email and try again.');
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
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 480 ? 22 : 30),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _codeSent ? _buildOtpStep(context) : _buildEmailStep(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _buildEmailStep(BuildContext context) => Form(
        key: _emailForm,
        child: Column(
          key: const ValueKey('first_run_email'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const MeritBrand(),
            const SizedBox(height: 30),
            Text('Set up your system', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            const Text(
              'Set up the first Owner account using Email OTP verification.',
              style: TextStyle(color: Color(0xFF667894)),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _sendSetupOtp(),
              decoration: const InputDecoration(
                labelText: 'Owner email address',
                prefixIcon: Icon(Icons.mail_outline),
                helperText: 'Must match the email approved by your system operator.',
              ),
              validator: (value) => value == null || !value.trim().contains('@') ? 'Enter a valid email address.' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
            ],
            if (_notice != null) ...[
              const SizedBox(height: 14),
              Text(_notice!, style: const TextStyle(color: Color(0xFF16794B))),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy ? null : _sendSetupOtp,
              icon: _busy
                  ? const ThinkingOrbsLoader(size: 18, label: 'Sending code')
                  : const Icon(Icons.send_rounded),
              label: Text(_busy ? 'Sending code…' : 'Send setup code'),
            ),
            const SizedBox(height: 14),
            Center(
              child: Tooltip(
                triggerMode: TooltipTriggerMode.tap,
                message: 'This one-time setup closes permanently after the first Owner account is secured.',
                child: TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('About first-time setup'),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildOtpStep(BuildContext context) => Form(
        key: _otpForm,
        child: Column(
          key: const ValueKey('first_run_otp'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const MeritBrand(),
            const SizedBox(height: 24),
            Text('Enter setup verification code', style: Theme.of(context).textTheme.headlineMedium),
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
              onFieldSubmitted: (_) => _verifySetupOtp(),
              decoration: const InputDecoration(
                labelText: '6-digit code',
                prefixIcon: Icon(Icons.pin_outlined),
                hintText: '123456',
              ),
              validator: (value) => value == null || value.trim().length < 6 ? 'Enter the full verification code.' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
            ],
            if (_notice != null) ...[
              const SizedBox(height: 14),
              Text(_notice!, style: const TextStyle(color: Color(0xFF16794B))),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy ? null : _verifySetupOtp,
              icon: _busy
                  ? const ThinkingOrbsLoader(size: 18, label: 'Verifying code')
                  : const Icon(Icons.check_rounded),
              label: Text(_busy ? 'Verifying…' : 'Verify & Continue Setup'),
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
                  onPressed: _busy ? null : _sendSetupOtp,
                  child: const Text('Resend code'),
                ),
              ],
            ),
          ],
        ),
      );
}
