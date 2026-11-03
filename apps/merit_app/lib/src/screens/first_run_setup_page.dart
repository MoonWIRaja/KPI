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
                  padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 480 ? 22 : 30),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const MeritBrand(),
                        const SizedBox(height: 30),
                        Text('Set up your system', style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 6),
                        const Text('Create the first Owner account.', style: TextStyle(color: Color(0xFF667894))),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.username, AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Owner email',
                            prefixIcon: Icon(Icons.mail_outline),
                            helperText: 'Use the email approved by your system operator.',
                          ),
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
                          label: Text(_busy ? 'Checking account…' : 'Continue Owner setup'),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Tooltip(
                            triggerMode: TooltipTriggerMode.tap,
                            message: 'This one-time setup closes after the first Owner account is secured.',
                            child: TextButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.info_outline, size: 16),
                              label: const Text('About first-time setup'),
                            ),
                          ),
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
