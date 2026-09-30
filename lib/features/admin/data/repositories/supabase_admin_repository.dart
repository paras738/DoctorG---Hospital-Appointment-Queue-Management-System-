import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client.dart';
import '../../doctor_directory/domain/models/doctor_model.dart';
import '../../reviews/data/repositories/supabase_reviews_repository.dart';
import '../../reviews/domain/models/review_report_model.dart';
import '../../reviews/domain/repositories/reviews_repository.dart';
import '../domain/repositories/admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  try {
    final supabase = ref.watch(supabaseClientProvider);
    final reviewsRepo = ref.watch(reviewsRepositoryProvider);
    return SupabaseAdminRepository(supabase, reviewsRepo);
  } catch (_) {
    final reviewsRepo = ref.watch(reviewsRepositoryProvider);
    return SupabaseAdminRepository(null, reviewsRepo);
  }
});

class SupabaseAdminRepository implements AdminRepository {
  final SupabaseClient? _supabase;
  final ReviewsRepository _reviewsRepo;

  // In-memory fallback for admin queue
  static final List<DoctorModel> _unverifiedDoctors = [
    DoctorModel(
      id: 'doc-unverified-1',
      fullName: 'Dr. Vikram Malhotra',
      registrationNumber: 'KMC-56789-IND',
      specialization: 'Orthopedic Surgeon',
      experienceYears: 12,
      consultationFee: 700.0,
      languages: const ['English', 'Hindi', 'Kannada'],
      isVerified: false,
      isAvailableToday: true,
      isAvailableNow: false,
      avgConsultationMinutes: 20,
      reviewCount: 0,
      avgRating: 0.0,
      bayesianScore: 3.5,
      isTopRated: false,
      hospitalName: 'Apollo Hospital, Seshadripuram',
      hospitalAddress: 'Sheshadripuram, Bengaluru',
    ),
    DoctorModel(
      id: 'doc-unverified-2',
      fullName: 'Dr. Neha Agrawal',
      registrationNumber: 'DMC-90214-IND',
      specialization: 'Dermatologist',
      experienceYears: 8,
      consultationFee: 600.0,
      languages: const ['English', 'Hindi'],
      isVerified: false,
      isAvailableToday: true,
      isAvailableNow: false,
      avgConsultationMinutes: 15,
      reviewCount: 0,
      avgRating: 0.0,
      bayesianScore: 3.5,
      isTopRated: false,
      hospitalName: 'Manipal Hospital, Old Airport Rd',
      hospitalAddress: 'HAL Airport Road, Bengaluru',
    ),
  ];

  SupabaseAdminRepository(this._supabase, this._reviewsRepo);

  @override
  Future<List<DoctorModel>> getUnverifiedDoctors() async {
    if (_supabase != null) {
      try {
        final response = await _supabase!
            .from('doctors')
            .select(
              '*, profiles:id(full_name, photo_url), doctor_hospitals(hospitals(name, address))',
            )
            .eq('is_verified', false)
            .order('created_at', ascending: false);

        final rawList = response as List<dynamic>;
        if (rawList.isNotEmpty) {
          return rawList.map((j) {
            final p = j['profiles'] as Map<String, dynamic>?;
            final dh =
                (j['doctor_hospitals'] as List<dynamic>?)?.firstOrNull
                    as Map<String, dynamic>?;
            final h = dh?['hospitals'] as Map<String, dynamic>?;

            return DoctorModel(
              id: j['id'] as String,
              fullName: p?['full_name'] as String? ?? 'Doctor',
              registrationNumber: j['registration_number'] as String,
              specialization: j['specialization'] as String,
              experienceYears: (j['experience_years'] as num).toInt(),
              consultationFee: (j['consultation_fee'] as num).toDouble(),
              languages:
                  (j['languages'] as List<dynamic>?)?.cast<String>() ??
                  ['English'],
              isVerified: false,
              isAvailableToday: j['is_available_today'] as bool? ?? true,
              isAvailableNow: j['is_available_now'] as bool? ?? false,
              avgConsultationMinutes:
                  (j['avg_consultation_minutes'] as num?)?.toInt() ?? 15,
              reviewCount: 0,
              avgRating: 0.0,
              bayesianScore: 3.5,
              isTopRated: false,
              hospitalName: h?['name'] as String?,
              hospitalAddress: h?['address'] as String?,
            );
          }).toList();
        }
      } catch (_) {}
    }

    return _unverifiedDoctors.where((d) => !d.isVerified).toList();
  }

  @override
  Future<void> verifyDoctor(String doctorId) async {
    if (_supabase != null) {
      try {
        await _supabase!
            .from('doctors')
            .update({'is_verified': true})
            .eq('id', doctorId);
      } catch (_) {}
    }

    final index = _unverifiedDoctors.indexWhere((d) => d.id == doctorId);
    if (index != -1) {
      _unverifiedDoctors.removeAt(index);
    }
  }

  @override
  Future<void> rejectDoctor(String doctorId, String reason) async {
    if (_supabase != null) {
      try {
        await _supabase!.from('doctors').delete().eq('id', doctorId);
      } catch (_) {}
    }

    _unverifiedDoctors.removeWhere((d) => d.id == doctorId);
  }

  @override
  Future<List<ReviewReportModel>> getFlaggedReviews() {
    return _reviewsRepo.getPendingReviewReports();
  }

  @override
  Future<void> moderateReview({
    required String reportId,
    required String action,
    String? reviewId,
  }) {
    return _reviewsRepo.resolveReviewReport(
      reportId: reportId,
      action: action,
      reviewId: reviewId,
    );
  }
}
