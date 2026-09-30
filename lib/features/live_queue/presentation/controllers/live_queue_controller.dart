import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/supabase_queue_repository.dart';
import '../../domain/models/queue_state_model.dart';
import '../../domain/models/queue_token_model.dart';

@immutable
class LiveQueueParams {
  final String doctorId;
  final DateTime date;
  final int userToken;

  const LiveQueueParams({
    required this.doctorId,
    required this.date,
    this.userToken = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiveQueueParams &&
          runtimeType == other.runtimeType &&
          doctorId == other.doctorId &&
          date.year == other.date.year &&
          date.month == other.date.month &&
          date.day == other.date.day &&
          userToken == other.userToken;

  @override
  int get hashCode =>
      doctorId.hashCode ^
      date.year.hashCode ^
      date.month.hashCode ^
      date.day.hashCode ^
      userToken.hashCode;
}

/// AutoDispose StreamProvider for a single doctor's live queue state
/// Strict Free-Tier Rule: Unsubscribes immediately when leaving screen
final liveQueueStreamProvider = StreamProvider.autoDispose
    .family<QueueStateModel?, LiveQueueParams>((ref, params) {
      final repository = ref.watch(queueRepositoryProvider);
      return repository.watchQueueState(params.doctorId, params.date);
    });

/// Doctor Queue State for Doctor / OPD Clinic Dashboard
@immutable
class DoctorQueueState {
  final bool isLoading;
  final String? errorMessage;
  final QueueStateModel? queueState;
  final List<QueueTokenModel> tokens;
  final bool isAvailableNow;
  final int gracePeriodRemainingSeconds;
  final String? gracePeriodTokenId;

  const DoctorQueueState({
    this.isLoading = false,
    this.errorMessage,
    this.queueState,
    this.tokens = const [],
    this.isAvailableNow = true,
    this.gracePeriodRemainingSeconds = 0,
    this.gracePeriodTokenId,
  });

  QueueTokenModel? get currentServingToken {
    if (queueState == null) return null;
    try {
      return tokens.firstWhere(
        (t) => t.tokenNumber == queueState!.currentToken,
      );
    } catch (_) {
      return null;
    }
  }

  int get waitingCount =>
      tokens.where((t) => t.status == TokenProgressStatus.waiting).length;
  int get completedCount =>
      tokens.where((t) => t.status == TokenProgressStatus.completed).length;
  int get skippedCount =>
      tokens.where((t) => t.status == TokenProgressStatus.skipped).length;

  DoctorQueueState copyWith({
    bool? isLoading,
    String? errorMessage,
    QueueStateModel? queueState,
    List<QueueTokenModel>? tokens,
    bool? isAvailableNow,
    int? gracePeriodRemainingSeconds,
    String? gracePeriodTokenId,
  }) {
    return DoctorQueueState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      queueState: queueState ?? this.queueState,
      tokens: tokens ?? this.tokens,
      isAvailableNow: isAvailableNow ?? this.isAvailableNow,
      gracePeriodRemainingSeconds:
          gracePeriodRemainingSeconds ?? this.gracePeriodRemainingSeconds,
      gracePeriodTokenId: gracePeriodTokenId ?? this.gracePeriodTokenId,
    );
  }
}

class DoctorQueueController extends StateNotifier<DoctorQueueState> {
  final Ref _ref;
  final String doctorId;
  final DateTime _today = DateTime.now();

  DoctorQueueController(this._ref, this.doctorId)
    : super(const DoctorQueueState(isLoading: true)) {
    loadQueue();
  }

  Future<void> loadQueue() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repo = _ref.read(queueRepositoryProvider);
      final qState = await repo.getQueueState(doctorId, _today);
      final tokens = await repo.getClinicQueueTokens(doctorId, _today);

      state = state.copyWith(
        isLoading: false,
        queueState: qState,
        tokens: tokens,
      );
    } catch (err) {
      state = state.copyWith(isLoading: false, errorMessage: err.toString());
    }
  }

  Future<void> callNextPatient() async {
    try {
      final repo = _ref.read(queueRepositoryProvider);
      await repo.callNextPatient(doctorId, _today);
      await loadQueue();
    } catch (err) {
      state = state.copyWith(errorMessage: 'Failed to call next patient: $err');
    }
  }

  Future<void> markComplete(String tokenId) async {
    try {
      final repo = _ref.read(queueRepositoryProvider);
      await repo.updateTokenStatus(tokenId, TokenProgressStatus.completed);
      await loadQueue();
    } catch (err) {
      state = state.copyWith(errorMessage: 'Failed to complete token: $err');
    }
  }

  Future<void> markNoShowWithGrace(String tokenId) async {
    // 5-minute grace period alert for patient
    state = state.copyWith(
      gracePeriodTokenId: tokenId,
      gracePeriodRemainingSeconds: 300,
    );

    try {
      final repo = _ref.read(queueRepositoryProvider);
      await repo.updateTokenStatus(tokenId, TokenProgressStatus.skipped);
      await loadQueue();
    } catch (err) {
      state = state.copyWith(errorMessage: 'Failed to mark no-show: $err');
    }
  }

  Future<void> announceDelay(int minutes) async {
    try {
      final repo = _ref.read(queueRepositoryProvider);
      await repo.setDoctorDelay(doctorId, _today, minutes);
      await loadQueue();
    } catch (err) {
      state = state.copyWith(errorMessage: 'Failed to update delay: $err');
    }
  }

  Future<void> toggleQueuePause() async {
    final current = state.queueState?.status ?? QueueStatus.active;
    final nextStatus = current == QueueStatus.active
        ? QueueStatus.paused
        : QueueStatus.active;

    try {
      final repo = _ref.read(queueRepositoryProvider);
      await repo.setQueueStatus(doctorId, _today, nextStatus);
      await loadQueue();
    } catch (err) {
      state = state.copyWith(errorMessage: 'Failed to update queue: $err');
    }
  }

  Future<void> toggleAvailability(bool val) async {
    state = state.copyWith(isAvailableNow: val);
    try {
      final repo = _ref.read(queueRepositoryProvider);
      await repo.toggleDoctorAvailability(doctorId, val);
    } catch (err) {
      state = state.copyWith(
        errorMessage: 'Failed to toggle availability: $err',
      );
    }
  }
}

final doctorQueueControllerProvider = StateNotifierProvider.autoDispose
    .family<DoctorQueueController, DoctorQueueState, String>((ref, doctorId) {
      return DoctorQueueController(ref, doctorId);
    });
