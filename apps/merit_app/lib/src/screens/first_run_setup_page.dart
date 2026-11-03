import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/merit_brand.dart';
import '../widgets/thinking_orbs_loader.dart';

class FirstRunSetupPage extends StatefulWidget {
  const FirstRunSetupPage({super.key});

  @override
  State<FirstRunSetupPage> createState() => _FirstRunSetupPageState();
}

class _FirstRunSetupPageState extends State<FirstRunSetupPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _continueSetup() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on AuthException {
      if (mounted) setState(() => _error = 'Invalid email or password. Check the Owner account provided by the operator.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to connect right now. Check the configuration and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
                  padding: const EdgeInsets.all(30),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const MeritBrand(),
                        const SizedBox(height: 34),
                        Text('Set up your system', style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 8),
                        const Text('Welcome to Merit Tracker. Set up the system owner before inviting other users.'),
                        const SizedBox(height: 22),
                        const _SetupStep(number: '01', title: 'Verify the Owner account', detail: 'Use the email address approved and verified by the operator.'),
                        const SizedBox(height: 14),
                        const _SetupStep(number: '02', title: 'Set up the administrator account', detail: 'After signing in, the setup wizard will ask for a name and a new password.'),
                        const SizedBox(height: 14),
                        const _SetupStep(number: '03', title: 'Protect access', detail: 'Enable MFA before viewing data or inviting staff.'),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.username, AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Owner email', prefixIcon: Icon(Icons.mail_outline)),
                          validator: (value) => value == null || !value.trim().contains('@') ? 'Enter a valid email address.' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: !_showPassword,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => _continueSetup(),
                          decoration: InputDecoration(
                            labelText: 'Temporary password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _showPassword ? 'Hide password' : 'Show password',
                              onPressed: () => setState(() => _showPassword = !_showPassword),
                              icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            ),
                          ),
                          validator: (value) => value == null || value.isEmpty ? 'Enter the Owner account password.' : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
                        ],
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _busy ? null : _continueSetup,
                          icon: _busy
                              ? const ThinkingOrbsLoader(size: 18, label: 'Checking account')
                              : const Icon(Icons.arrow_forward_rounded),
                          label: Text(_busy ? 'Checking accountâ€¦' : 'Continue Owner setup'),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Owner setup can only be claimed once. After completion, this wizard closes and regular sign-in is used.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Color(0xFF667894)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({required this.number, required this.title, required this.detail});

  final String number;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFFE9EEFF), borderRadius: BorderRadius.circular(9)),
            child: Text(number, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF344A91))),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF172033))),
                const SizedBox(height: 2),
                Text(detail, style: const TextStyle(fontSize: 12, color: Color(0xFF667894))),
              ],
            ),
          ),
        ],
      );
}
