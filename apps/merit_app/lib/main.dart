import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var configured = supabaseUrl.startsWith('https://') && supabasePublishableKey.isNotEmpty;

  if (configured) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabasePublishableKey,
        authOptions: const FlutterAuthClientOptions(persistSession: false),
      );
    } catch (_) {
      configured = false;
    }
  }

  runApp(MeritTrackerApp(configured: configured));
}
