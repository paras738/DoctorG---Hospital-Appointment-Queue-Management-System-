import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../doctor_directory/domain/models/doctor_model.dart';
import '../../reviews/domain/models/review_report_model.dart';
import '../data/repositories/supabase_admin_repository.dart';

final unverifiedDoctorsListProvider =
    FutureProvider.autoDispose<List<DoctorModel>>((ref) async {
      final repo = ref.watch(adminRepositoryProvider);
      return repo.getUnverifiedDoctors();
    });

final flaggedReviewsListProvider =
    FutureProvider.autoDispose<List<ReviewReportModel>>((ref) async {
      final repo = ref.watch(adminRepositoryProvider);
      return repo.getFlaggedReviews();
    });

class AdminController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  AdminController(this._ref) : super(const AsyncValue.data(null));

  Future<void> approveDoctor(String doctorId) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(adminRepositoryProvider);
      await repo.verifyDoctor(doctorId);
      _ref.invalidate(unverifiedDoctorsListProvider);
      state = const AsyncValue.data(null);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
    }
  }

  Future<void> rejectDoctor(String doctorId, String reason) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(adminRepositoryProvider);
      await repo.rejectDoctor(doctorId, reason);
      _ref.invalidate(unverifiedDoctorsListProvider);
      state = const AsyncValue.data(null);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
    }
  }

  Future<void> moderateReview({
    required String reportId,
    required String action,
    String? reviewId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(adminRepositoryProvider);
      await repo.moderateReview(
        reportId: reportId,
        action: action,
        reviewId: reviewId,
      );
      _ref.invalidate(flaggedReviewsListProvider);
      state = const AsyncValue.data(null);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
    }
  }
}

final adminControllerProvider =
    StateNotifierProvider.autoDispose<AdminController, AsyncValue<void>>((ref) {
      return AdminController(ref);
    });
