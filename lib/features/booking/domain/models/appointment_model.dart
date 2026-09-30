class AppointmentModel {
  final String id;
  final String doctorId;
  final String doctorName;
  final String doctorSpecialization;
  final String? doctorPhotoUrl;
  final String? hospitalName;
  final String patientId;
  final String patientName;
  final String? familyMemberId;
  final String slotId;
  final DateTime appointmentDate;
  final DateTime slotStart;
  final DateTime slotEnd;
  final int tokenNumber;
  final String status; // 'pending_payment', 'confirmed', 'in_progress', 'completed', 'cancelled', 'no_show'
  final String bookingType; // 'online_full', 'clinic_pay'
  final double consultationFee;
  final DateTime createdAt;

  const AppointmentModel({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.doctorSpecialization,
    this.doctorPhotoUrl,
    this.hospitalName,
    required this.patientId,
    required this.patientName,
    this.familyMemberId,
    required this.slotId,
    required this.appointmentDate,
    required this.slotStart,
    required this.slotEnd,
    required this.tokenNumber,
    required this.status,
    required this.bookingType,
    required this.consultationFee,
    required this.createdAt,
  });

  bool get isUpcoming =>
      status == 'confirmed' && slotStart.isAfter(DateTime.now());

  bool get canCancel {
    if (status != 'confirmed' && status != 'pending_payment') return false;
    // Clinic pay bookings can be cancelled anytime before slot; online pay has 2-hour window
    if (bookingType == 'clinic_pay') return true;
    return slotStart.difference(DateTime.now()).inHours >= 2;
  }

  String get formattedSlotTime {
    final hour = slotStart.hour;
    final minute = slotStart.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$h12:$minute $ampm';
  }

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    String docName = 'Doctor';
    String docSpec = 'Specialist';
    String? docPhoto;
    String? hospName;
    double fee = 500.0;

    if (json['doctors'] != null && json['doctors'] is Map) {
      final doc = json['doctors'] as Map<String, dynamic>;
      docSpec = doc['specialization'] as String? ?? 'General Physician';
      docPhoto = doc['photo_url'] as String?;
      fee = (doc['consultation_fee'] as num?)?.toDouble() ?? 500.0;
      if (doc['profiles'] != null && doc['profiles'] is Map) {
        docName = doc['profiles']['full_name'] as String? ?? 'Doctor';
      }
    }

    return AppointmentModel(
      id: json['id'] as String,
      doctorId: json['doctor_id'] as String,
      doctorName: json['doctor_name'] as String? ?? docName,
      doctorSpecialization: json['specialization'] as String? ?? docSpec,
      doctorPhotoUrl: json['doctor_photo_url'] as String? ?? docPhoto,
      hospitalName: json['hospital_name'] as String? ?? hospName,
      patientId: json['patient_id'] as String,
      patientName: json['patient_name'] as String? ?? 'Patient',
      familyMemberId: json['family_member_id'] as String?,
      slotId: json['slot_id'] as String,
      appointmentDate: DateTime.parse(json['appointment_date'] as String),
      slotStart: json['slot_start'] != null
          ? DateTime.parse(json['slot_start'] as String)
          : DateTime.now(),
      slotEnd: json['slot_end'] != null
          ? DateTime.parse(json['slot_end'] as String)
          : DateTime.now().add(const Duration(minutes: 15)),
      tokenNumber: (json['token_number'] as num?)?.toInt() ?? 1,
      status: json['status'] as String? ?? 'confirmed',
      bookingType: json['booking_type'] as String? ?? 'online_full',
      consultationFee: (json['consultation_fee'] as num?)?.toDouble() ?? fee,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'doctor_id': doctorId,
      'doctor_name': doctorName,
      'specialization': doctorSpecialization,
      'patient_id': patientId,
      'patient_name': patientName,
      'family_member_id': familyMemberId,
      'slot_id': slotId,
      'appointment_date': appointmentDate.toIso8601String().split('T')[0],
      'slot_start': slotStart.toIso8601String(),
      'slot_end': slotEnd.toIso8601String(),
      'token_number': tokenNumber,
      'status': status,
      'booking_type': bookingType,
      'consultation_fee': consultationFee,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
