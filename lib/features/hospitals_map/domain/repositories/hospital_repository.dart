import '../models/hospital_model.dart';

abstract class HospitalRepository {
  /// Fetch nearby hospitals using PostGIS spatial RPC with GIST index
  Future<List<HospitalModel>> getNearbyHospitals({
    required double userLat,
    required double userLng,
    double radiusMeters = 10000.0,
  });

  /// On-demand route calculation (called ONLY when user taps a hospital card)
  /// Caches result in Hive and re-fetches only if user moves >= 200m
  Future<HospitalRouteModel> getRouteToHospital({
    required String hospitalId,
    required double startLat,
    required double startLng,
    required double destLat,
    required double destLng,
  });
}
