import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/cache/cache_service.dart';
import 'core/network/supabase_client.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize environment & configuration
  await AppConfig.initialize();

  // 2. Initialize local offline cache (Hive)
  await CacheService.initialize();

  // 3. Initialize Supabase Auth & PostgreSQL Client
  try {
    await SupabaseService.initialize();
  } catch (e) {
    // Log initialization warning if running offline or without credentials
    debugPrint('Supabase initialization note: $e');
  }

  // 4. Run application inside Riverpod ProviderScope
  runApp(const ProviderScope(child: DoctorGApp()));
}
