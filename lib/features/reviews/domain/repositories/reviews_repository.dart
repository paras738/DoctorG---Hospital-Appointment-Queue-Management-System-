import '../../doctor_directory/domain/models/doctor_review_model.dart';
import '../models/review_report_model.dart';

abstract class ReviewsRepository {
  /// Submit a verified review for a completed appointment
  Future<DoctorReviewModel> submitVerifiedReview({
    required String appointmentId,
    required String doctorId,
    required String patientId,
    required int rating,
    String? comment,
  });

  /// Doctor submits official reply to a patient review
  Future<void> replyToReview({
    required String reviewId,
    required String doctorReply,
  });

  /// Flag / report inappropriate review for admin moderation
  Future<void> reportReview({
    required String reviewId,
    required String reporterId,
    required String reason,
  });

  /// Fetch all reviews for a specific doctor
  Future<List<DoctorReviewModel>> getDoctorReviews(String doctorId);

  /// Admin view: Fetch flagged reviews awaiting moderation
  Future<List<ReviewReportModel>> getPendingReviewReports();

  /// Admin action: Resolve report by deleting review or dismissing report
  Future<void> resolveReviewReport({
    required String reportId,
    required String action, // 'dismiss' or 'delete_review'
    String? reviewId,
  });
}
