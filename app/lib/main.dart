import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'data/demo_repository.dart';
import 'data/repository.dart';
import 'data/supabase_repository.dart';
import 'services/bible_store.dart';
import 'state/providers.dart';

/// Run against Supabase:
///   flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co --dart-define=SUPABASE_ANON_KEY=...
/// Run the offline demo (no backend; sign-in code 123456):
///   flutter run --dart-define=DEMO=true
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const _demo = bool.fromEnvironment('DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([initializeDateFormatting('fr'), initializeDateFormatting('en')]);
  final prefs = await SharedPreferences.getInstance();

  final Repository repo;
  if (_demo || _supabaseUrl.isEmpty) {
    if (!_demo) debugPrint('SUPABASE_URL not set: starting in demo mode.');
    repo = DemoRepository();
  } else {
    await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseAnonKey);
    repo = SupabaseRepository(Supabase.instance.client);
  }

  runApp(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(repo),
      prefsProvider.overrideWithValue(prefs),
      bibleStoreProvider.overrideWithValue(kIsWeb ? MemoryBibleStore() : FileBibleStore()),
    ],
    child: const EvangelisApp(),
  ));
}
