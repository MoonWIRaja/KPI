import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/thinking_orbs_loader.dart';

class MfaGate extends StatefulWidget {
  const MfaGate({required this.onComplete, super.key});

  final VoidCallback onComplete;

  @override
  State<MfaGate> createState() => _MfaGateState();
}

class _MfaGateState extends State<MfaGate> {
  final _code = TextEditingController();
  String? _factorId;
  String? _secret;
  String? _error;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = Supabase.instance.client.auth;
      final assurance = auth.mfa.getAuthenticatorAssuranceLevel();
      if (assurance.currentLevel?.name == 'aal2') {
        widget.onComplete();
        return;
      }

      final factors = await auth.mfa.listFactors();
      final verified = factors.totp.where((factor) => factor.status.name == 'verified').toList();
      if (verified.isNotEmpty) {
        _factorId = verified.first.id;
      } else {
        for (final unverified in factors.all.where((factor) => factor.status.name == 'unverified')) {
          await auth.mfa.unenroll(unverified.id);
        }
        final enrolled = await auth.mfa.enroll(
          factorType: FactorType.totp,
          issuer: 'Merit Tracker',
          friendlyName: 'Merit Tracker authenticator',
        );
        final totp = enrolled.totp;
        if (totp == null) throw StateError('TOTP enrollment data was not returned');
        _factorId = enrolled.id;
        _secret = totp.secret;
      }
    } catch (_) {
      _error = 'Additional verification could not be set up. Try again or contact the system owner.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    final factorId = _factorId;
    if (factorId == null || !RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Enter the six-digit code from your authenticator app.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.mfa.challengeAndVerify(factorId: factorId, code: code);
      widget.onComplete();
    } catch (_) {
      setState(() => _error = 'The code is invalid or expired. Check your device clock and try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enrolling = _secret != null;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: _loading
                    ? const Center(child: Padding(padding: EdgeInsets.all(24), child: ThinkingOrbsLoader(size: 40)))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.verified_user_outlined, size: 32, color: Color(0xFF245CEB)),
                          const SizedBox(height: 18),
                          Text(enrolling ? 'Enable two-step verification' : 'Verify your sign-in', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 10),
                          Text(enrolling
                              ? 'Administrator accounts and accounts with management permissions must use an authenticator code. Add this key manually in your authenticator app.'
                              : 'Enter the current code from your authenticator app to access protected features.'),
                          if (enrolling) ...[
                            const SizedBox(height: 18),
                            const Text('Setup key â€” store it securely and do not share it.'),
                            const SizedBox(height: 8),
                            SelectableText(_secret ?? '', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(ClipboardData(text: _secret ?? ''));
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Setup key copied.')));
                                },
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text('Copy key'),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          TextField(
                            controller: _code,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _verify(),
                            decoration: const InputDecoration(labelText: '6-digit code', prefixIcon: Icon(Icons.password)),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
                            if (_factorId == null)
                              TextButton(onPressed: _loading ? null : _prepare, child: const Text('Try again')),
                          ],
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _submitting || _factorId == null ? null : _verify,
                              child: Text(_submitting ? 'Verifyingâ€¦' : 'Verify and continue'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(child: TextButton(onPressed: () => Supabase.instance.client.auth.signOut(), child: const Text('Sign out'))),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
