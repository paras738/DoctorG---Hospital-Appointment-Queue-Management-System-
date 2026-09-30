import '../models/doctor_model.dart';
import '../models/doctor_filter.dart';
import '../models/doctor_review_model.dart';

abstract class DoctorRepository {
  /// Fetch paginated doctors for a city applying search query and dynamic filters
  Future<List<DoctorModel>> getDoctors({
    required String city,
    String? searchQuery,
    required DoctorFilter filter,
    int page = 0,
    int pageSize = 20,
    double? userLat,
    double? userLng,
  });

  /// Fetch single doctor detailed profile
  Future<DoctorModel?> getDoctorById(
    String doctorId, {
    double? userLat,
    double? userLng,
  });

  /// Fetch reviews for a specific doctor
  Future<List<DoctorReviewModel>> getDoctorReviews(
    String doctorId, {
    int limit = 20,
  });

  /// List of specializations available in the system
  Future<List<String>> getSpecializations();

  /// List of common symptom-to-specialization shortcuts
  Future<List<Map<String, String>>> getPopularSymptoms();
}
