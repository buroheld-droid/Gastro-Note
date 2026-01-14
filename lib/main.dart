import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

const _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://rctzvwhhvccczidnhtdq.supabase.co',
);

const _supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJjdHp2d2hodmNjY3ppZG5odGRxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgzMjk5MTIsImV4cCI6MjA4MzkwNTkxMn0.U0R48UXApLPTtAI1dPx2P8qFDmco7jMlU4_PTmpX_i4',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnonKey,
  );

  runApp(const ProviderScope(child: GastroNoteApp()));
}
