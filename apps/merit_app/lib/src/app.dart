import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/home_shell.dart';
import 'screens/login_page.dart';
import 'screens/password_setup_page.dart';

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
        if (session == null) return const LoginPage();
        if (_recoveringPassword || snapshot.data?.event == AuthChangeEvent.passwordRecovery) {
          return const PasswordSetupPage(isRecovery: true);
        }
        return const HomeShell();
      },
    );
  }
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
                  Text('Sambungan belum disediakan', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  const Text('Konfigurasikan Supabase URL dan publishable key sebagai nilai build GitHub Actions. Jangan masukkan service-role key di aplikasi.'),
                  const SizedBox(height: 18),
                  const SelectableText('SUPABASE_URL\nSUPABASE_PUBLISHABLE_KEY'),
                  const SizedBox(height: 10),
                  const Text('Tetapan ini ialah maklumat client yang boleh dilihat pengguna laman. RLS mesti melindungi semua data. Akaun baharu tetap invite-only.'),
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
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFF172033), borderRadius: BorderRadius.circular(9)),
          child: const Text('M', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Text('Merit Tracker', style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
