import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doctorg/features/doctor_directory/domain/models/doctor_review_model.dart';
import 'package:doctorg/features/reviews/domain/models/review_report_model.dart';
import 'package:doctorg/features/reviews/data/repositories/supabase_reviews_repository.dart';
import 'package:doctorg/features/admin/data/repositories/supabase_admin_repository.dart';
import 'package:doctorg/core/localization/locale_controller.dart';

void main() {
  group('DoctorReviewModel & ReviewReportModel Tests', () {
    final now = DateTime.now();

    test('DoctorReviewModel parses JSON with joined profile', () {
      final json = {
        'id': 'rev-101',
        'appointment_id': 'app-202',
        'doctor_id': 'doc-303',
        'patient_id': 'pat-404',
        'profiles': {'full_name': 'Aarav Patel'},
        'rating': 5,
        'comment': 'Accurate diagnosis and friendly doctor.',
        'doctor_reply': 'Thank you! Take care.',
        'doctor_replied_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
      };

      final review = DoctorReviewModel.fromJson(json);

      expect(review.id, equals('rev-101'));
      expect(review.patientName, equals('Aarav Patel'));
      expect(review.rating, equals(5));
      expect(review.doctorReply, equals('Thank you! Take care.'));
      expect(review.doctorRepliedAt, isNotNull);
    });

    test('ReviewReportModel parses status flags correctly', () {
      final report = ReviewReportModel(
        id: 'rep-1',
        reviewId: 'rev-1',
        reporterId: 'user-1',
        reason: 'Spam promotion',
        status: 'pending',
        createdAt: now,
      );

      expect(report.isPending, isTrue);
      expect(report.isResolved, isFalse);
      expect(report.isDismissed, isFalse);

      final json = report.toJson();
      expect(json['reason'], equals('Spam promotion'));
      expect(json['status'], equals('pending'));
    });
  });

  group('SupabaseReviewsRepository Operations', () {
    final repo = SupabaseReviewsRepository(null);
    const docId = 'test-doc-review-99';

    test('submits verified review and adds to doctor review list', () async {
      final review = await repo.submitVerifiedReview(
        appointmentId: 'app-verified-1',
        doctorId: docId,
        patientId: 'patient-verified-1',
        rating: 5,
        comment: 'Great clinic experience and minimal waiting.',
      );

      expect(review.rating, equals(5));
      expect(review.comment, contains('Great clinic experience'));

      final list = await repo.getDoctorReviews(docId);
      expect(list.any((r) => r.appointmentId == 'app-verified-1'), isTrue);
    });

    test('allows doctor to submit official reply', () async {
      final list = await repo.getDoctorReviews(docId);
      final target = list.first;

      await repo.replyToReview(
        reviewId: target.id,
        doctorReply: 'Glad to assist you with your recovery!',
      );

      final updatedList = await repo.getDoctorReviews(docId);
      final updated = updatedList.firstWhere((r) => r.id == target.id);
      expect(
        updated.doctorReply,
        equals('Glad to assist you with your recovery!'),
      );
    });

    test('reports review and queues for admin moderation', () async {
      await repo.reportReview(
        reviewId: 'rev-to-flag',
        reporterId: 'doc-user',
        reason: 'Abusive language',
      );

      final pending = await repo.getPendingReviewReports();
      expect(pending.any((p) => p.reason == 'Abusive language'), isTrue);
    });
  });

  group('AdminRepository Doctor Verification & Moderation', () {
    final reviewsRepo = SupabaseReviewsRepository(null);
    final adminRepo = SupabaseAdminRepository(null, reviewsRepo);

    test('fetches unverified doctors queue', () async {
      final unverified = await adminRepo.getUnverifiedDoctors();
      expect(unverified, isNotEmpty);
      expect(unverified.every((d) => !d.isVerified), isTrue);
    });

    test('approves and verifies doctor license', () async {
      final unverified = await adminRepo.getUnverifiedDoctors();
      final targetDoc = unverified.first;

      await adminRepo.verifyDoctor(targetDoc.id);

      final remaining = await adminRepo.getUnverifiedDoctors();
      expect(remaining.any((d) => d.id == targetDoc.id), isFalse);
    });

    test(
      'moderates flagged reviews by dismissing or resolving report',
      () async {
        final reports = await adminRepo.getFlaggedReviews();
        expect(reports, isNotEmpty);
        final targetReport = reports.first;

        await adminRepo.moderateReview(
          reportId: targetReport.id,
          action: 'dismiss',
        );

        final remainingReports = await adminRepo.getFlaggedReviews();
        expect(remainingReports.any((r) => r.id == targetReport.id), isFalse);
      },
    );
  });

  group('LocaleNotifier Bilingual Localization Switcher', () {
    test('initializes with English and toggles to Hindi', () {
      final notifier = LocaleNotifier();
      expect(notifier.state.languageCode, equals('en'));
      expect(notifier.isHindi, isFalse);

      notifier.toggleLanguage();
      expect(notifier.state.languageCode, equals('hi'));
      expect(notifier.isHindi, isTrue);

      notifier.toggleLanguage();
      expect(notifier.state.languageCode, equals('en'));
      expect(notifier.isHindi, isFalse);

      notifier.setLocale(const Locale('hi', ''));
      expect(notifier.state.languageCode, equals('hi'));
    });
  });
}
