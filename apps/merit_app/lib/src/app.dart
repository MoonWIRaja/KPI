import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/first_run_setup_page.dart';
import 'screens/home_shell.dart';
import 'screens/initial_owner_setup_page.dart';
import 'screens/login_page.dart';
import 'screens/password_setup_page.dart';
import 'widgets/merit_brand.dart';
import 'widgets/thinking_orbs_loader.dart';

class MeritTrackerApp extends StatelessWidget {
  const MeritTrackerApp({required this.configured, super.key});

  final bool configured;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF245CEB);
    return MaterialApp(
      title: 'Merit Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed, surface: const Color(0xFFF7F9FC)),
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF7F9FC), surfaceTintColor: Colors.transparent),
        cardTheme: CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFFE3E9F2)),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: Color(0xFFD9E1EC)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(44, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Color(0xFF141C2E)),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF141C2E)),
          titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF141C2E)),
          bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF34435D)),
          bodySmall: TextStyle(fontSize: 12, color: Color(0xFF667894)),
        ),
      ),
      home: !configured ? const _ConfigurationRequired() : const _AuthGate(),
      builder: (context, child) => Title(
        title: 'Merit Tracker',
        color: const Color(0xFFF7F9FC),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _recoveringPassword = false;
  bool _holdForAnimation = false;
  late final Stream<AuthState> _authChanges;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _authChanges = client.auth.onAuthStateChange;
    _authSubscription = _authChanges.listen((state) {
      if (!mounted) return;
      if (state.event == AuthChangeEvent.passwordRecovery && !_recoveringPassword) {
        setState(() => _recoveringPassword = true);
      } else if (state.event == AuthChangeEvent.signedOut && _recoveringPassword) {
        setState(() => _recoveringPassword = false);
      } else if (state.event == AuthChangeEvent.signedIn && !_holdForAnimation) {
        setState(() => _holdForAnimation = true);
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (mounted) setState(() => _holdForAnimation = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: _authChanges,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? client.auth.currentSession;
        if (session == null || _holdForAnimation) return const _FirstRunGate();
        if (_recoveringPassword || snapshot.data?.event == AuthChangeEvent.passwordRecovery) {
          return const PasswordSetupPage(isRecovery: true);
        }
        return _AuthenticatedAccountGate(key: ValueKey(session.user.id), userId: session.user.id, email: session.user.email ?? '');
      },
    );
  }
}

class _FirstRunGate extends StatefulWidget {
  const _FirstRunGate();

  @override
  State<_FirstRunGate> createState() => _FirstRunGateState();
}

class _FirstRunGateState extends State<_FirstRunGate> {
  String _state = 'loading';

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      final setupComplete = await Supabase.instance.client.rpc('is_initial_owner_setup_complete') as bool;
      if (mounted) setState(() => _state = setupComplete ? 'login' : 'first-run');
    } catch (_) {
      // The first-run sign-in accepts only operator-created Auth accounts.
      // If the status RPC is missing, let the owner continue; the authenticated
      // gate and trusted bootstrap RPC still enforce whether setup is allowed.
      if (mounted) setState(() => _state = 'first-run');
    }
  }

  @override
  Widget build(BuildContext context) => switch (_state) {
        'first-run' => const FirstRunSetupPage(),
        'login' => const LoginPage(),
        _ => const Scaffold(body: Center(child: ThinkingOrbsLoader(size: 44))),
      };
}

class _AuthenticatedAccountGate extends StatefulWidget {
  const _AuthenticatedAccountGate({required this.userId, required this.email, super.key});

  final String userId;
  final String email;

  @override
  State<_AuthenticatedAccountGate> createState() => _AuthenticatedAccountGateState();
}

class _AuthenticatedAccountGateState extends State<_AuthenticatedAccountGate> {
  String _state = 'loading';

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    setState(() => _state = 'loading');
    try {
      final client = Supabase.instance.client;
      final profile = await client.from('profiles').select('user_id').eq('user_id', widget.userId).maybeSingle();
      if (!mounted) return;
      if (profile != null) {
        setState(() => _state = 'home');
        return;
      }
      final canClaimOwner = await client.rpc('can_claim_initial_owner') as bool;
      if (mounted) setState(() => _state = canClaimOwner ? 'owner-setup' : 'unlinked');
    } catch (_) {
      if (mounted) setState(() => _state = 'setup-unavailable');
    }
  }

  @override
  Widget build(BuildContext context) => switch (_state) {
        'home' => const HomeShell(),
        'owner-setup' => InitialOwnerSetupPage(email: widget.email, onComplete: _resolve),
        'unlinked' => _AccountPendingPage(onSignOut: () => Supabase.instance.client.auth.signOut()),
        'setup-unavailable' => _AccountSetupUnavailablePage(onRetry: _resolve),
        _ => const Scaffold(body: Center(child: ThinkingOrbsLoader(size: 44))),
      };
}

class _AccountPendingPage extends StatelessWidget {
  const _AccountPendingPage({required this.onSignOut});

  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) => _AccountMessagePage(
        title: 'Account not linked',
        message: 'Contact the system owner for an invitation or access. Public account registration is disabled.',
        actionLabel: 'Sign out',
        onAction: onSignOut,
      );
}

class _AccountSetupUnavailablePage extends StatelessWidget {
  const _AccountSetupUnavailablePage({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => _AccountMessagePage(
        title: 'Supabase setup is unavailable',
        message: 'Make sure the application migrations have been applied to the Supabase project, then try again.',
        actionLabel: 'Try again',
        onAction: onRetry,
        showSignOut: true,
      );
}

class _AccountMessagePage extends StatefulWidget {
  const _AccountMessagePage({required this.title, required this.message, required this.actionLabel, required this.onAction, this.showSignOut = false});

  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;
  final bool showSignOut;

  @override
  State<_AccountMessagePage> createState() => _AccountMessagePageState();
}

class _AccountMessagePageState extends State<_AccountMessagePage> {
  bool _busy = false;

  Future<void> _act() async {
    setState(() => _busy = true);
    try {
      await widget.onAction();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.lock_outline, size: 34, color: Color(0xFF245CEB)),
                      const SizedBox(height: 16),
                      Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(widget.message),
                      const SizedBox(height: 18),
                      FilledButton(onPressed: _busy ? null : _act, child: Text(_busy ? 'Please wait...' : widget.actionLabel)),
                      if (widget.showSignOut)
                        TextButton(
                          onPressed: _busy ? null : () => Supabase.instance.client.auth.signOut(),
                          child: const Text('Sign out'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _ConfigurationRequired extends StatelessWidget {
  const _ConfigurationRequired();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _BrandMark(),
                  const SizedBox(height: 24),
                  Text('Connection not configured', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  const Text('Configure the Supabase URL and publishable key as GitHub Actions build values. Never put a service-role key in the app.'),
                  const SizedBox(height: 18),
                  const SelectableText('SUPABASE_URL\nSUPABASE_PUBLISHABLE_KEY'),
                  const SizedBox(height: 10),
                  const Text('These client values are visible to site visitors. Row-level security must protect all data. New accounts remain invite-only.'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => const MeritBrand(compact: true);
}
