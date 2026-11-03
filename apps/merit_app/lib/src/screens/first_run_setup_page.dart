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

  void _openExistingCode() {
    if (!_emailForm.currentState!.validate()) return;
    setState(() {
      _error = null;
      _notice = null;
      _codeSent = true;
    });
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
              _error = 'Unauthorized owner email.';
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

      if (mounted) setState(() => _codeSent = true);
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.message.toLowerCase().contains('rate limit') || e.statusCode == '429') {
        setState(() {
          _codeSent = true;
          _notice = 'A code was recently sent. Enter it below or wait 60s to resend.';
        });
      } else {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Connection error. Please try again.');
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
          child: SmoothStepSwitcher(
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
            const SizedBox(height: 22),
            Row(
              children: [
                Text('Owner Setup', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(width: 4),
                const InfoTooltip(
                  message: 'Initial system setup. Only the designated bootstrap email configured in Supabase can claim the primary Owner account.',
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Enter owner email to receive a 6-digit code.',
              style: TextStyle(color: Color(0xFF667894), fontSize: 13),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email, AutofillHints.username],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _sendSetupOtp(),
              decoration: const InputDecoration(
                labelText: 'Owner email',
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
              onPressed: _busy ? null : _sendSetupOtp,
              icon: _busy
                  ? const ThinkingOrbsLoader(size: 18, label: 'Sending')
                  : const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                _busy ? 'Sending…' : 'Send setup code',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _busy ? null : _openExistingCode,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Already have a code?', style: TextStyle(fontSize: 12.5)),
              ),
            ),
          ],
        ),
      );
}
