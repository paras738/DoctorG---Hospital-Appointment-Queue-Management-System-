import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/hospital_model.dart';
import '../../data/repositories/supabase_hospital_repository.dart';
import '../../../doctor_directory/presentation/controllers/doctor_directory_controller.dart';

enum HospitalViewMode { list, map }

final hospitalViewModeProvider = StateProvider<HospitalViewMode>(
  (ref) => HospitalViewMode.map,
);

final hospitalRadiusMetersProvider = StateProvider<double>(
  (ref) => 10000.0,
); // 10 km default

final selectedHospitalProvider = StateProvider<HospitalModel?>((ref) => null);

final nearbyHospitalsProvider = FutureProvider<List<HospitalModel>>((
  ref,
) async {
  final repo = ref.watch(hospitalRepositoryProvider);
  final loc = ref.watch(userLocationProvider);
  final radius = ref.watch(hospitalRadiusMetersProvider);

  // Default coordinate for Bengaluru (Vidhana Soudha area) if location not yet acquired
  final userLat = loc?['lat'] ?? 12.9716;
  final userLng = loc?['lng'] ?? 77.5946;

  return repo.getNearbyHospitals(
    userLat: userLat,
    userLng: userLng,
    radiusMeters: radius,
  );
});

final hospitalRouteProvider =
    FutureProvider.family<HospitalRouteModel, HospitalModel>((
      ref,
      hospital,
    ) async {
      final repo = ref.watch(hospitalRepositoryProvider);
      final loc = ref.watch(userLocationProvider);

      final userLat = loc?['lat'] ?? 12.9716;
      final userLng = loc?['lng'] ?? 77.5946;

      return repo.getRouteToHospital(
        hospitalId: hospital.id,
        startLat: userLat,
        startLng: userLng,
        destLat: hospital.latitude,
        destLng: hospital.longitude,
      );
    });
