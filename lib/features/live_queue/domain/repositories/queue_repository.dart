import '../models/queue_state_model.dart';
import '../models/queue_token_model.dart';

abstract class QueueRepository {
  /// Realtime stream scoped ONLY to a single doctor's queue state for today
  /// Respects strict Supabase free-tier limits by filtering on doctor_id and queue_date
  Stream<QueueStateModel?> watchQueueState(String doctorId, DateTime date);

  /// Fetch single point-in-time snapshot of queue state
  Future<QueueStateModel?> getQueueState(String doctorId, DateTime date);

  /// Fetch all patient tokens for a doctor's OPD session today (doctor/receptionist view)
  Future<List<QueueTokenModel>> getClinicQueueTokens(
    String doctorId,
    DateTime date,
  );

  /// Doctor Action: Advance queue to next patient
  Future<void> callNextPatient(String doctorId, DateTime date);

  /// Doctor Action: Update individual patient token status (waiting, called, withDoctor, completed, skipped)
  Future<void> updateTokenStatus(String tokenId, TokenProgressStatus status);

  /// Doctor Action: Announce OPD delay in minutes
  Future<void> setDoctorDelay(String doctorId, DateTime date, int delayMinutes);

  /// Doctor Action: Pause, resume, or end the active queue
  Future<void> setQueueStatus(
    String doctorId,
    DateTime date,
    QueueStatus status,
  );

  /// Doctor Action: Toggle 'Available Now' status (updates doctors table and Bayesian boost)
  Future<void> toggleDoctorAvailability(String doctorId, bool isAvailableNow);
}
