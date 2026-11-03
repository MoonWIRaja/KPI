import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/merit_brand.dart';

class InitialOwnerSetupPage extends StatefulWidget {
  const InitialOwnerSetupPage({required this.email, required this.onComplete, super.key});

  final String email;
  final Future<void> Function() onComplete;

  @override
  State<InitialOwnerSetupPage> createState() => _InitialOwnerSetupPageState();
}

class _InitialOwnerSetupPageState extends State<InitialOwnerSetupPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _finishSetup() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = Supabase.instance.client.auth;
      await auth.updateUser(UserAttributes(password: _password.text));
      await Supabase.instance.client.rpc(
        'bootstrap_initial_owner',
        params: {'display_name_input': _name.text.trim()},
      );
      await widget.onComplete();
    } on AuthException {
      if (mounted) setState(() => _error = 'Kata laluan tidak memenuhi polisi projek. Semak syarat dan cuba lagi.');
    } on PostgrestException catch (error) {
      if (mounted) {
        _error = error.message.contains('not available')
            ? 'Akaun ini tidak dibenarkan menjadi Owner pertama. Semak e-mel bootstrap dan hubungi operator.'
            : 'Setup Owner belum tersedia pada Supabase. Pastikan migration setup telah digunakan.';
        setState(() {});
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Setup tidak berjaya. Semak sambungan dan cuba semula.');
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
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const MeritBrand(),
                        const SizedBox(height: 24),
                        Text('Sediakan akaun Admin (Owner)', style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 8),
                        const Text(
                          'Ini setup sekali sahaja untuk pemantau sistem. E-mel ini mesti telah dibenarkan oleh operator Supabase dan disahkan.',
                        ),
                        const SizedBox(height: 20),
                        const Text('Akaun yang sedang log masuk', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 5),
                        SelectableText(widget.email, style: const TextStyle(color: Color(0xFF34435D))),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: [LengthLimitingTextInputFormatter(160)],
                          decoration: const InputDecoration(labelText: 'Nama pemantau sistem'),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Masukkan nama.' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: !_showPassword,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: InputDecoration(
                            labelText: 'Kata laluan baharu',
                            helperText: 'Minimum 12 aksara.',
                            suffixIcon: IconButton(
                              tooltip: _showPassword ? 'Sembunyikan kata laluan' : 'Tunjukkan kata laluan',
                              onPressed: () => setState(() => _showPassword = !_showPassword),
                              icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            ),
                          ),
                          validator: (value) => value == null || value.length < 12 ? 'Kata laluan minimum 12 aksara.' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirm,
                          obscureText: !_showPassword,
                          autofillHints: const [AutofillHints.newPassword],
                          onFieldSubmitted: (_) => _finishSetup(),
                          decoration: const InputDecoration(labelText: 'Ulang kata laluan baharu'),
                          validator: (value) => value != _password.text ? 'Kata laluan tidak sepadan.' : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
                        ],
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _busy ? null : _finishSetup,
                          icon: _busy
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.verified_user_outlined),
                          label: Text(_busy ? 'Menyediakan akaun…' : 'Sediakan akaun Admin'),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Selepas setup, anda perlu aktifkan TOTP sebelum membuka data staff.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Color(0xFF667894)),
                        ),
                        TextButton(
                          onPressed: _busy ? null : () => Supabase.instance.client.auth.signOut(),
                          child: const Text('Log keluar'),
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
