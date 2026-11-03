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
      setState(() => _error = 'Kata laluan tidak dapat dikemas kini. Semak polisi kata laluan dan cuba lagi.');
    } on PostgrestException {
      setState(() => _error = 'Status jemputan tidak dapat disahkan. Hubungi pemantau sistem.');
    } catch (_) {
      setState(() => _error = 'Kata laluan tidak dapat dikemas kini. Cuba lagi sebentar nanti.');
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
                      Text(widget.isRecovery ? 'Tetapkan kata laluan baharu' : 'Aktifkan akaun anda', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      const Text('Gunakan sekurang-kurangnya 12 aksara. Jangan guna kata laluan yang sama dengan akaun lain.'),
                      const SizedBox(height: 18),
                      TextFormField(controller: _password, obscureText: true, autofillHints: const [AutofillHints.newPassword], decoration: const InputDecoration(labelText: 'Kata laluan baharu'), validator: (value) => value == null || value.length < 12 ? 'Kata laluan minimum 12 aksara.' : null),
                      const SizedBox(height: 12),
                      TextFormField(controller: _confirm, obscureText: true, onFieldSubmitted: (_) => _save(), decoration: const InputDecoration(labelText: 'Ulang kata laluan'), validator: (value) => value != _password.text ? 'Kata laluan tidak sepadan.' : null),
                      if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Color(0xFFB42318)))],
                      const SizedBox(height: 18),
                      FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Mengemas kini…' : 'Simpan kata laluan')),
                      const SizedBox(height: 8),
                      const Text('Selepas disimpan, log masuk semula menggunakan kata laluan baharu.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF667894))),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
