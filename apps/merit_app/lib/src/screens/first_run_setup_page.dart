import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/glassy_otp_view.dart';
import '../widgets/merit_brand.dart';
import '../widgets/thinking_orbs_loader.dart';

class FirstRunSetupPage extends StatefulWidget {
  const FirstRunSetupPage({super.key});

  @override
  State<FirstRunSetupPage> createState() => _FirstRunSetupPageState();
}

class _FirstRunSetupPageState extends State<FirstRunSetupPage> {
  final _emailForm = GlobalKey<FormState>();
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

  Future<void> _sendSetupOtp() async {
    if (!_emailForm.currentState!.validate()) return;
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

  Future<bool> _verifySetupOtp(String token) async {
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
      if (mounted) setState(() => _error = 'Invalid or expired setup code. (${e.message})');
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
                    key: const ValueKey('setup_otp_view'),
                    email: _email.text.trim(),
                    isInitialSetup: true,
                    busy: _busy,
                    error: _error,
                    notice: _notice,
                    onVerify: _verifySetupOtp,
                    onResend: _sendSetupOtp,
                    onChangeEmail: _resetEmail,
                  )
                : _buildSetupEmailForm(context),
          ),
        ),
      );

  Widget _buildSetupEmailForm(BuildContext context) => Form(
        key: _emailForm,
        child: Column(
          key: const ValueKey('setup_email_form'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const MeritBrand(compact: true),
            const SizedBox(height: 26),
            Text('Set up Merit Tracker', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            const Text(
              'Initial system configuration. Enter the designated owner email to receive a setup code.',
              style: TextStyle(color: Color(0xFF667894)),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email, AutofillHints.username],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _sendSetupOtp(),
              decoration: const InputDecoration(
                labelText: 'Designated Owner Email',
                prefixIcon: Icon(Icons.shield_outlined),
                hintText: 'e.g. owner@organization.com',
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
              onPressed: _busy ? null : _sendSetupOtp,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _busy
                  ? const ThinkingOrbsLoader(size: 18, label: 'Sending setup code')
                  : const Icon(Icons.send_rounded),
              label: Text(_busy ? 'Sending code…' : 'Send setup code'),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'First-run setup only allows the configured bootstrap email address.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF8896AB)),
              ),
            ),
          ],
        ),
      );
}
