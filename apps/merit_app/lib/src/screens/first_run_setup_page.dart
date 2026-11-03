import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/merit_brand.dart';

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
      if (mounted) setState(() => _error = 'E-mel atau kata laluan tidak sah. Semak akaun Owner yang disediakan operator.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Tidak dapat menyambung sekarang. Semak konfigurasi dan cuba lagi.');
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
                        Text('Sediakan sistem anda', style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 8),
                        const Text('Selamat datang ke Merit Tracker. Mulakan dengan setup pemilik sistem sebelum menjemput pengguna lain.'),
                        const SizedBox(height: 22),
                        const _SetupStep(number: '01', title: 'Sahkan akaun Owner', detail: 'Gunakan e-mel yang telah diluluskan dan disahkan oleh operator.'),
                        const SizedBox(height: 14),
                        const _SetupStep(number: '02', title: 'Tetapkan maklumat Admin', detail: 'Selepas log masuk, wizard akan meminta nama dan kata laluan baharu.'),
                        const SizedBox(height: 14),
                        const _SetupStep(number: '03', title: 'Lindungi akses', detail: 'Aktifkan MFA sebelum membuka data atau menjemput staff.'),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.username, AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'E-mel Owner', prefixIcon: Icon(Icons.mail_outline)),
                          validator: (value) => value == null || !value.trim().contains('@') ? 'Masukkan e-mel yang sah.' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: !_showPassword,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => _continueSetup(),
                          decoration: InputDecoration(
                            labelText: 'Kata laluan sementara',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _showPassword ? 'Sembunyikan kata laluan' : 'Tunjukkan kata laluan',
                              onPressed: () => setState(() => _showPassword = !_showPassword),
                              icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            ),
                          ),
                          validator: (value) => value == null || value.isEmpty ? 'Masukkan kata laluan akaun Owner.' : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
                        ],
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _busy ? null : _continueSetup,
                          icon: _busy
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.arrow_forward_rounded),
                          label: Text(_busy ? 'Menyemak akaun' : 'Teruskan setup Owner'),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Setup Owner hanya boleh dituntut sekali. Selepas selesai, wizard ini ditutup dan log masuk biasa digunakan.',
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
