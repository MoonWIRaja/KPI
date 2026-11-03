import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/merit_brand.dart';
import '../widgets/thinking_orbs_loader.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on AuthException {
      setState(() => _error = 'Invalid email or password. Check your details and try again.');
    } catch (_) {
      setState(() => _error = 'Unable to sign in right now. Please try again shortly.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestReset() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter your email first to request a recovery link.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: Uri.base.replace(query: '', fragment: '').toString(),
      );
      setState(() => _notice = 'If an account exists, recovery instructions will be sent by email.');
    } catch (_) {
      setState(() => _error = 'The request could not be sent. Try again or contact the system owner.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const MeritBrand(compact: true),
                      const SizedBox(height: 30),
                      Text('Sign in', style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 6),
                      const Text('Sign in with your invited account.', style: TextStyle(color: Color(0xFF667894))),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username, AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                        validator: (value) => value == null || !value.trim().contains('@') ? 'Enter a valid email address.' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: !_showPassword,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _signIn(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _showPassword ? 'Hide password' : 'Show password',
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                            icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Enter your password.' : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(onPressed: _busy ? null : _requestReset, child: const Text('Forgot password?')),
                      ),
                      if (_error != null) _MessageBox(text: _error!, isError: true),
                      if (_notice != null) _MessageBox(text: _notice!, isError: false),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _busy ? null : _signIn,
                        icon: _busy
                            ? const ThinkingOrbsLoader(size: 18, label: 'Signing in')
                            : const Icon(Icons.arrow_forward),
                        label: Text(_busy ? 'Signing in...' : 'Sign in'),
                      ),
                      const SizedBox(height: 10),
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
