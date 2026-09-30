import 'package:flutter_dotenv/flutter_dotenv.dart';

/// DoctorG Application Configuration
/// Enforces Free-Tier Resource Constraints and Safe Defaults
class AppConfig {
  static late final String supabaseUrl;
  static late final String supabaseAnonKey;
  static late final String razorpayKeyId;
  static late final String googleMapsApiKey;

  // Free-Tier Limits & Performance Constants
  static const int paginationPageSize = 20;
  static const int maxDoctorPhotoSizeBytes = 200 * 1024; // 200 KB max
  static const int routeCacheThresholdMeters =
      200; // Refresh route only if user moves >= 200m
  static const int cacheDurationMinutes = 15;
  static const int maxRealtimeRetries = 3;

  // Medical Disclaimer
  static const String medicalDisclaimer =
      'DoctorG is a doctor discovery and queue management platform, '
      'not a substitute for professional medical diagnosis or emergency care. '
      'In case of emergency, please visit the nearest hospital immediately.';

  /// Initializes environment configurations with safe fallback defaults
  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // In tests or environments without .env file, fallbacks are applied
    }

    supabaseUrl =
        dotenv.env['SUPABASE_URL'] ?? 'https://placeholder.supabase.co';
    supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? 'placeholder-anon-key';
    razorpayKeyId = dotenv.env['RAZORPAY_KEY_ID'] ?? 'rzp_test_placeholder';
    googleMapsApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  }
}
