import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/glassy_otp_view.dart';
import '../widgets/merit_brand.dart';
import '../widgets/thinking_orbs_loader.dart';

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
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _finishSetup() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.rpc(
        'bootstrap_initial_owner',
        params: {'display_name_input': _name.text.trim()},
      );
      await widget.onComplete();
    } on PostgrestException catch (error) {
      if (mounted) {
        _error = error.message.contains('not available')
            ? 'This account is not authorized to become the first Owner. Check the bootstrap email and contact the operator.'
            : 'Owner setup is not available on Supabase. Make sure the setup migration has been applied.';
        setState(() {});
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Setup failed. Check the connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: GlassyCardFrame(
          maxWidth: 460,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const MeritBrand(compact: true),
                const SizedBox(height: 24),
                Text('Set up administrator account (Owner)', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Text(
                  'Your email has been verified via OTP. Enter your full name to claim and permanently lock the primary Owner account.',
                  style: TextStyle(color: Color(0xFF667894)),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16794B).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_outlined, size: 16, color: Color(0xFF16794B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SelectableText(
                          widget.email,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF16794B)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [LengthLimitingTextInputFormatter(160)],
                  onFieldSubmitted: (_) => _finishSetup(),
                  decoration: const InputDecoration(
                    labelText: 'System owner full name',
                    hintText: 'e.g. Moon',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Enter your name.' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _busy ? null : _finishSetup,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _busy
                      ? const ThinkingOrbsLoader(size: 18, label: 'Securing Owner account')
                      : const Icon(Icons.verified_user_outlined),
                  label: Text(_busy ? 'Securing Owner account…' : 'Complete Owner Setup'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _busy ? null : () => Supabase.instance.client.auth.signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      );
}
