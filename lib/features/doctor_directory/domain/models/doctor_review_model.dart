class DoctorReviewModel {
  final String id;
  final String appointmentId;
  final String doctorId;
  final String patientId;
  final String patientName;
  final int rating;
  final String? comment;
  final String? doctorReply;
  final DateTime? doctorRepliedAt;
  final DateTime createdAt;

  const DoctorReviewModel({
    required this.id,
    required this.appointmentId,
    required this.doctorId,
    required this.patientId,
    required this.patientName,
    required this.rating,
    this.comment,
    this.doctorReply,
    this.doctorRepliedAt,
    required this.createdAt,
  });

  factory DoctorReviewModel.fromJson(Map<String, dynamic> json) {
    String pName = 'Verified Patient';
    if (json['profiles'] != null && json['profiles'] is Map) {
      final p = json['profiles'] as Map<String, dynamic>;
      if (p['full_name'] != null && (p['full_name'] as String).isNotEmpty) {
        pName = p['full_name'] as String;
      }
    }

    return DoctorReviewModel(
      id: json['id'] as String,
      appointmentId: json['appointment_id'] as String,
      doctorId: json['doctor_id'] as String,
      patientId: json['patient_id'] as String,
      patientName: pName,
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String?,
      doctorReply: json['doctor_reply'] as String?,
      doctorRepliedAt: json['doctor_replied_at'] != null
          ? DateTime.tryParse(json['doctor_replied_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'appointment_id': appointmentId,
      'doctor_id': doctorId,
      'patient_id': patientId,
      'patient_name': patientName,
      'rating': rating,
      'comment': comment,
      'doctor_reply': doctorReply,
      'doctor_replied_at': doctorRepliedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
