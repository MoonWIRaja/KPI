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
        backgroundColor: const Color(0xFF060911),
        body: Stack(
          children: [
            const MetallicRibbonsBackground(),
            GlassyCardFrame(
              maxWidth: 460,
              child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: const MeritBrand(compact: true),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Complete Owner Setup',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Your email has been verified via OTP. Enter your full name to permanently claim and secure the primary Owner account.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_outlined, size: 16, color: Color(0xFF34D399)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.email,
                              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFA7F3D0), fontSize: 13),
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
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'System owner full name',
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        hintText: 'e.g. Moon',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                        prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF94A3B8)),
                        fillColor: const Color(0xFF0F172A).withValues(alpha: 0.5),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.8),
                        ),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Enter your name.' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35)),
                        ),
                        child: Text(_error!, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12)),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : _finishSetup,
                        icon: _busy
                            ? const ThinkingOrbsLoader(size: 18, label: 'Securing Owner account')
                            : const Icon(Icons.verified_user_outlined, size: 18),
                        label: Text(
                          _busy ? 'Securing Owner account…' : 'Complete Owner Setup',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF10B981).withValues(alpha: 0.4),
                          disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: TextButton(
                        onPressed: _busy ? null : () => Supabase.instance.client.auth.signOut(),
                        child: const Text('Sign out', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}
