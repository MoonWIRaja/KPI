import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PasswordSetupPage extends StatefulWidget {
  const PasswordSetupPage({required this.isRecovery, super.key});
  final bool isRecovery;

  @override
  State<PasswordSetupPage> createState() => _PasswordSetupPageState();
}

class _PasswordSetupPageState extends State<PasswordSetupPage> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      final client = Supabase.instance.client;
      await client.auth.updateUser(UserAttributes(password: _password.text));
      if (!widget.isRecovery) await client.rpc('complete_password_setup');
      await client.auth.signOut();
    } on AuthException {
      setState(() => _error = 'Password could not be updated. Check the password policy and try again.');
    } on PostgrestException {
      setState(() => _error = 'Invitation status could not be verified. Contact the system owner.');
    } catch (_) {
      setState(() => _error = 'Password could not be updated. Please try again shortly.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 440,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _form,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const Icon(Icons.lock_reset_outlined, size: 34, color: Color(0xFF245CEB)),
                      const SizedBox(height: 18),
                      Text(widget.isRecovery ? 'Set a new password' : 'Activate your account', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      const Text('Use at least 12 characters. Do not reuse a password from another account.'),
                      const SizedBox(height: 18),
                      TextFormField(controller: _password, obscureText: true, autofillHints: const [AutofillHints.newPassword], decoration: const InputDecoration(labelText: 'New password'), validator: (value) => value == null || value.length < 12 ? 'Password must be at least 12 characters.' : null),
                      const SizedBox(height: 12),
                      TextFormField(controller: _confirm, obscureText: true, onFieldSubmitted: (_) => _save(), decoration: const InputDecoration(labelText: 'Confirm password'), validator: (value) => value != _password.text ? 'Passwords do not match.' : null),
                      if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Color(0xFFB42318)))],
                      const SizedBox(height: 18),
                      FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Updating...' : 'Save password')),
                      const SizedBox(height: 8),
                      const Text('After saving, sign in again with your new password.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF667894))),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
