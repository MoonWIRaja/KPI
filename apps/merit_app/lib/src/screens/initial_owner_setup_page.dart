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
            ? 'Unauthorized owner email.'
            : 'Setup migration not applied.';
        setState(() {});
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Setup failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: GlassyCardFrame(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const MeritBrand(compact: true),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Text('Owner Profile', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(width: 4),
                    const InfoTooltip(
                      message: 'Claims and permanently locks the primary Owner account. Future logins use Email OTP.',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Enter your display name to finish setup.',
                  style: TextStyle(color: Color(0xFF667894), fontSize: 13),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16794B).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_outlined, size: 16, color: Color(0xFF16794B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.email,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF16794B), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [LengthLimitingTextInputFormatter(160)],
                  onFieldSubmitted: (_) => _finishSetup(),
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    hintText: 'e.g. Moon',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Enter your name.' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: Color(0xFFB42318), fontSize: 12.5)),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _finishSetup,
                  icon: _busy
                      ? const ThinkingOrbsLoader(size: 18, label: 'Saving')
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    _busy ? 'Saving…' : 'Complete Setup',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _busy ? null : () => Supabase.instance.client.auth.signOut(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Sign out', style: TextStyle(fontSize: 12.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
