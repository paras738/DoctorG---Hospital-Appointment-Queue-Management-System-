import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService();
});

/// Local offline cache service implemented using Hive
/// Enforces: Server is always source of truth; never cache payments or sensitive tokens.
class CacheService {
  static const String doctorBoxName = 'doctor_cache';
  static const String userPrefsBoxName = 'user_prefs_cache';
  static const String routeBoxName = 'route_cache';

  static Future<void> initialize() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox<String>(doctorBoxName),
      Hive.openBox<String>(userPrefsBoxName),
      Hive.openBox<String>(routeBoxName),
    ]);
  }

  /// Caches doctor list for a city with timestamp
  Future<void> cacheDoctors(
    String city,
    List<Map<String, dynamic>> doctors,
  ) async {
    final box = Hive.box<String>(doctorBoxName);
    final data = {
      'timestamp': DateTime.now().toIso8601String(),
      'doctors': doctors,
    };
    await box.put('doctors_$city', jsonEncode(data));
  }

  /// Retrieves cached doctor list if fresher than maxMinutes
  List<Map<String, dynamic>>? getCachedDoctors(
    String city, {
    int maxMinutes = 15,
  }) {
    final box = Hive.box<String>(doctorBoxName);
    final raw = box.get('doctors_$city');
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final timestamp = DateTime.parse(decoded['timestamp'] as String);
      if (DateTime.now().difference(timestamp).inMinutes > maxMinutes) {
        return null; // Stale cache
      }
      return (decoded['doctors'] as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  /// Caches user's selected city or last known coordinate
  Future<void> cacheLocation(String city, double lat, double lng) async {
    final box = Hive.box<String>(userPrefsBoxName);
    final data = {'city': city, 'latitude': lat, 'longitude': lng};
    await box.put('last_location', jsonEncode(data));
  }

  /// Retrieves last known location
  Map<String, dynamic>? getLastLocation() {
    final box = Hive.box<String>(userPrefsBoxName);
    final raw = box.get('last_location');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Clear all offline cached data (e.g. on user logout)
  Future<void> clearAll() async {
    await Future.wait([
      Hive.box<String>(doctorBoxName).clear(),
      Hive.box<String>(userPrefsBoxName).clear(),
      Hive.box<String>(routeBoxName).clear(),
    ]);
  }
}
