import '../../doctor_directory/domain/models/doctor_model.dart';
import '../../reviews/domain/models/review_report_model.dart';

abstract class AdminRepository {
  /// Fetch list of doctors awaiting medical license verification
  Future<List<DoctorModel>> getUnverifiedDoctors();

  /// Approve and mark doctor as verified
  Future<void> verifyDoctor(String doctorId);

  /// Reject doctor registration with feedback reason
  Future<void> rejectDoctor(String doctorId, String reason);

  /// Fetch flagged patient reviews awaiting moderation
  Future<List<ReviewReportModel>> getFlaggedReviews();

  /// Moderate flagged review (dismiss report or delete review)
  Future<void> moderateReview({
    required String reportId,
    required String action, // 'dismiss' or 'delete_review'
    String? reviewId,
  });
}
