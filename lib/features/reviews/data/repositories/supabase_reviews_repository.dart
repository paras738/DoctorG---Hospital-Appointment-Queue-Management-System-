import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/supabase_client.dart';
import '../../doctor_directory/domain/models/doctor_review_model.dart';
import '../domain/models/review_report_model.dart';
import '../domain/repositories/reviews_repository.dart';

final reviewsRepositoryProvider = Provider<ReviewsRepository>((ref) {
  try {
    final supabase = ref.watch(supabaseClientProvider);
    return SupabaseReviewsRepository(supabase);
  } catch (_) {
    return SupabaseReviewsRepository(null);
  }
});

class SupabaseReviewsRepository implements ReviewsRepository {
  final SupabaseClient? _supabase;
  final _uuid = const Uuid();

  // In-memory fallback storage
  static final Map<String, List<DoctorReviewModel>> _doctorReviews = {};
  static final List<ReviewReportModel> _pendingReports = [];

  SupabaseReviewsRepository(this._supabase);

  @override
  Future<DoctorReviewModel> submitVerifiedReview({
    required String appointmentId,
    required String doctorId,
    required String patientId,
    required int rating,
    String? comment,
  }) async {
    final now = DateTime.now();

    if (_supabase != null) {
      try {
        final res = await _supabase!
            .from('reviews')
            .insert({
              'appointment_id': appointmentId,
              'doctor_id': doctorId,
              'patient_id': patientId,
              'rating': rating,
              'comment': comment,
            })
            .select('*, profiles:patient_id(full_name)')
            .single();

        final created = DoctorReviewModel.fromJson(res);
        _doctorReviews.putIfAbsent(doctorId, () => []).insert(0, created);
        return created;
      } catch (_) {
        // Fallback to local memory storage
      }
    }

    final model = DoctorReviewModel(
      id: _uuid.v4(),
      appointmentId: appointmentId,
      doctorId: doctorId,
      patientId: patientId,
      patientName: 'Verified Patient',
      rating: rating,
      comment: comment,
      createdAt: now,
    );

    _doctorReviews.putIfAbsent(doctorId, () => []).insert(0, model);
    return model;
  }

  @override
  Future<void> replyToReview({
    required String reviewId,
    required String doctorReply,
  }) async {
    final now = DateTime.now();

    if (_supabase != null) {
      try {
        await _supabase!
            .from('reviews')
            .update({
              'doctor_reply': doctorReply,
              'doctor_replied_at': now.toIso8601String(),
            })
            .eq('id', reviewId);
      } catch (_) {}
    }

    // Update in-memory
    for (final list in _doctorReviews.values) {
      final index = list.indexWhere((r) => r.id == reviewId);
      if (index != -1) {
        final old = list[index];
        list[index] = DoctorReviewModel(
          id: old.id,
          appointmentId: old.appointmentId,
          doctorId: old.doctorId,
          patientId: old.patientId,
          patientName: old.patientName,
          rating: old.rating,
          comment: old.comment,
          doctorReply: doctorReply,
          doctorRepliedAt: now,
          createdAt: old.createdAt,
        );
        break;
      }
    }
  }

  @override
  Future<void> reportReview({
    required String reviewId,
    required String reporterId,
    required String reason,
  }) async {
    final now = DateTime.now();

    if (_supabase != null) {
      try {
        await _supabase!.from('review_reports').insert({
          'review_id': reviewId,
          'reporter_id': reporterId,
          'reason': reason,
          'status': 'pending',
        });
      } catch (_) {}
    }

    _pendingReports.add(
      ReviewReportModel(
        id: _uuid.v4(),
        reviewId: reviewId,
        reporterId: reporterId,
        reason: reason,
        status: 'pending',
        createdAt: now,
      ),
    );
  }

  @override
  Future<List<DoctorReviewModel>> getDoctorReviews(String doctorId) async {
    if (_supabase != null) {
      try {
        final response = await _supabase!
            .from('reviews')
            .select('*, profiles:patient_id(full_name)')
            .eq('doctor_id', doctorId)
            .order('created_at', ascending: false);

        final rawList = response as List<dynamic>;
        if (rawList.isNotEmpty) {
          final list = rawList
              .map((j) => DoctorReviewModel.fromJson(j as Map<String, dynamic>))
              .toList();
          _doctorReviews[doctorId] = list;
          return list;
        }
      } catch (_) {}
    }

    return _doctorReviews.putIfAbsent(doctorId, () {
      final now = DateTime.now();
      return [
        DoctorReviewModel(
          id: 'mock-rev-1',
          appointmentId: 'mock-app-1',
          doctorId: doctorId,
          patientId: 'mock-pat-1',
          patientName: 'Rohan Verma',
          rating: 5,
          comment: 'Dr. Rajesh Sharma is exceptional! Diagnosis was swift and accurate. The live queue saved me 2 hours in waiting.',
          doctorReply:
              'Thank you Rohan! Wishing you a speedy and complete recovery.',
          doctorRepliedAt: now.subtract(const Duration(days: 2)),
          createdAt: now.subtract(const Duration(days: 3)),
        ),
        DoctorReviewModel(
          id: 'mock-rev-2',
          appointmentId: 'mock-app-2',
          doctorId: doctorId,
          patientId: 'mock-pat-2',
          patientName: 'Aishwarya Sen',
          rating: 5,
          comment: 'Very polite doctor and supportive clinic staff. Clear explanation of prescription medications.',
          createdAt: now.subtract(const Duration(days: 6)),
        ),
      ];
    });
  }

  @override
  Future<List<ReviewReportModel>> getPendingReviewReports() async {
    if (_supabase != null) {
      try {
        final response = await _supabase!
            .from('review_reports')
            .select('*, reviews(*, profiles:patient_id(full_name))')
            .eq('status', 'pending')
            .order('created_at', ascending: false);

        final rawList = response as List<dynamic>;
        if (rawList.isNotEmpty) {
          return rawList
              .map((j) => ReviewReportModel.fromJson(j as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {}
    }

    if (_pendingReports.isEmpty) {
      _pendingReports.add(
        ReviewReportModel(
          id: 'rep-001',
          reviewId: 'mock-rev-flagged',
          reporterId: 'doc-user-1',
          reason: 'Irrelevant advertisement / spam comment posted.',
          status: 'pending',
          createdAt: DateTime.now().subtract(const Duration(hours: 4)),
          review: DoctorReviewModel(
            id: 'mock-rev-flagged',
            appointmentId: 'app-flagged',
            doctorId: '20000000-0000-0000-0000-000000000001',
            patientId: 'pat-flagged',
            patientName: 'Suspicious User',
            rating: 1,
            comment: 'Buy cheap health insurance at spamlink.com now!',
            createdAt: DateTime.now().subtract(const Duration(hours: 6)),
          ),
        ),
      );
    }

    return _pendingReports.where((r) => r.isPending).toList();
  }

  @override
  Future<void> resolveReviewReport({
    required String reportId,
    required String action,
    String? reviewId,
  }) async {
    final nextStatus = action == 'delete_review' ? 'resolved' : 'dismissed';

    if (_supabase != null) {
      try {
        if (action == 'delete_review' && reviewId != null) {
          await _supabase!.from('reviews').delete().eq('id', reviewId);
        }

        await _supabase!
            .from('review_reports')
            .update({'status': nextStatus})
            .eq('id', reportId);
      } catch (_) {}
    }

    final index = _pendingReports.indexWhere((r) => r.id == reportId);
    if (index != -1) {
      final old = _pendingReports[index];
      _pendingReports[index] = ReviewReportModel(
        id: old.id,
        reviewId: old.reviewId,
        reporterId: old.reporterId,
        reason: old.reason,
        status: nextStatus,
        createdAt: old.createdAt,
      );
    }
  }
}
