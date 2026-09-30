import 'package:flutter_test/flutter_test.dart';
import 'package:doctorg/features/live_queue/domain/models/queue_state_model.dart';
import 'package:doctorg/features/live_queue/domain/models/queue_token_model.dart';
import 'package:doctorg/features/live_queue/data/repositories/supabase_queue_repository.dart';

void main() {
  group('QueueStateModel Dynamic Calculations', () {
    final now = DateTime.now();

    final state = QueueStateModel(
      doctorId: 'doc-123',
      queueDate: now,
      currentToken: 8,
      lastToken: 25,
      avgMinutes: 15,
      delayMinutes: 0,
      status: QueueStatus.active,
      updatedAt: now,
    );

    test('calculates correct number of patients ahead', () {
      // User is token 12, serving 8 => tokens 9, 10, 11 are ahead (3 patients)
      expect(state.patientsAhead(12), equals(3));

      // User is token 9, serving 8 => 0 patients strictly ahead (next in line)
      expect(state.patientsAhead(9), equals(0));

      // User is token 8 (currently being served)
      expect(state.patientsAhead(8), equals(0));

      // User was token 5 (already completed)
      expect(state.patientsAhead(5), equals(0));
    });

    test('calculates dynamic estimated wait time with zero delay', () {
      // Token 12 with 4 tokens away @ 15 min each = 60 min
      expect(state.estimatedWaitMinutes(12), equals(60));

      // Token 9 (1 away) @ 15 min = 15 min
      expect(state.estimatedWaitMinutes(9), equals(15));

      // Past or current token has 0 wait
      expect(state.estimatedWaitMinutes(8), equals(0));
      expect(state.estimatedWaitMinutes(4), equals(0));
    });

    test('incorporates doctor OPD delay into estimated wait time', () {
      final delayedState = state.copyWith(delayMinutes: 20);

      // (12 - 8) * 15 + 20 = 80 min
      expect(delayedState.estimatedWaitMinutes(12), equals(80));

      // (9 - 8) * 15 + 20 = 35 min
      expect(delayedState.estimatedWaitMinutes(9), equals(35));
    });

    test('evaluates smart alert transitions accurately', () {
      // Past token -> completed
      expect(state.getAlertLevel(7), equals(QueueAlertLevel.completed));

      // Exact current token -> serving
      expect(state.getAlertLevel(8), equals(QueueAlertLevel.serving));

      // Next token in line (#9) -> nextInLine
      expect(state.getAlertLevel(9), equals(QueueAlertLevel.nextInLine));

      // 3 patients ahead (#12 -> 3 ahead) -> leaveNow
      expect(state.getAlertLevel(12), equals(QueueAlertLevel.leaveNow));

      // 2 patients ahead (#11 -> 2 ahead) -> leaveNow
      expect(state.getAlertLevel(11), equals(QueueAlertLevel.leaveNow));

      // Far ahead (#15 -> 6 ahead) -> waiting
      expect(state.getAlertLevel(15), equals(QueueAlertLevel.waiting));
    });

    test('serializes and deserializes JSON correctly', () {
      final json = state.toJson();
      expect(json['doctor_id'], equals('doc-123'));
      expect(json['current_token'], equals(8));
      expect(json['last_token'], equals(25));
      expect(json['status'], equals('active'));

      final parsed = QueueStateModel.fromJson(json);
      expect(parsed.doctorId, equals(state.doctorId));
      expect(parsed.currentToken, equals(state.currentToken));
      expect(parsed.lastToken, equals(state.lastToken));
      expect(parsed.status, equals(QueueStatus.active));
    });
  });

  group('QueueTokenModel', () {
    test('parses JSON and resolves patient details', () {
      final json = {
        'id': 'tok-1',
        'appointment_id': 'app-1',
        'doctor_id': 'doc-1',
        'queue_date': '2026-09-30',
        'token_number': 5,
        'status': 'called',
        'patient_name': 'Aarav Patel',
        'patient_phone': '+91 99999 11111',
        'patient_age': 32,
        'patient_gender': 'Male',
        'consultation_reason': 'Chest pain checkup',
      };

      final model = QueueTokenModel.fromJson(json);
      expect(model.id, equals('tok-1'));
      expect(model.tokenNumber, equals(5));
      expect(model.status, equals(TokenProgressStatus.called));
      expect(model.isCalled, isTrue);
      expect(model.patientName, equals('Aarav Patel'));
      expect(model.consultationReason, equals('Chest pain checkup'));
    });

    test('converts TokenProgressStatus to and from db string', () {
      expect(
        TokenProgressStatus.fromString('with_doctor'),
        equals(TokenProgressStatus.withDoctor),
      );
      expect(
        TokenProgressStatus.fromString('skipped'),
        equals(TokenProgressStatus.skipped),
      );
      expect(
        TokenProgressStatus.withDoctor.toDbString(),
        equals('with_doctor'),
      );
      expect(TokenProgressStatus.completed.toDbString(), equals('completed'));
    });
  });

  group('SupabaseQueueRepository Fallback & Controls', () {
    final repo = SupabaseQueueRepository(null);
    final today = DateTime.now();
    const docId = 'test-doc-555';

    test('initializes and returns default queue state', () async {
      final state = await repo.getQueueState(docId, today);
      expect(state, isNotNull);
      expect(state!.doctorId, equals(docId));
      expect(state.currentToken, isNonNegative);
    });

    test('calling next patient increments current token', () async {
      final initial = await repo.getQueueState(docId, today);
      final initialToken = initial!.currentToken;

      await repo.callNextPatient(docId, today);

      final updated = await repo.getQueueState(docId, today);
      expect(updated!.currentToken, equals(initialToken + 1));
    });

    test('announcing doctor delay updates delayMinutes', () async {
      await repo.setDoctorDelay(docId, today, 25);

      final updated = await repo.getQueueState(docId, today);
      expect(updated!.delayMinutes, equals(25));
    });

    test('pausing and resuming queue updates status', () async {
      await repo.setQueueStatus(docId, today, QueueStatus.paused);
      var state = await repo.getQueueState(docId, today);
      expect(state!.isPaused, isTrue);

      await repo.setQueueStatus(docId, today, QueueStatus.active);
      state = await repo.getQueueState(docId, today);
      expect(state!.isActive, isTrue);
    });
  });
}
