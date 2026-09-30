class SlotModel {
  final String id;
  final String doctorId;
  final DateTime slotDate;
  final DateTime slotStart;
  final DateTime slotEnd;
  final bool isLocked;
  final DateTime? lockedUntil;
  final String status; // 'available', 'booked', 'blocked'

  const SlotModel({
    required this.id,
    required this.doctorId,
    required this.slotDate,
    required this.slotStart,
    required this.slotEnd,
    required this.isLocked,
    this.lockedUntil,
    required this.status,
  });

  bool get isAvailable {
    if (status != 'available') return false;
    if (isLocked && lockedUntil != null) {
      // If locked and lock has not expired
      return DateTime.now().isAfter(lockedUntil!);
    }
    return true;
  }

  String get formattedTime {
    final hour = slotStart.hour;
    final minute = slotStart.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$h12:$minute $ampm';
  }

  String get timePeriod {
    final h = slotStart.hour;
    if (h < 12) return 'Morning';
    if (h < 16) return 'Afternoon';
    return 'Evening';
  }

  factory SlotModel.fromJson(Map<String, dynamic> json) {
    return SlotModel(
      id: json['id'] as String,
      doctorId: json['doctor_id'] as String,
      slotDate: DateTime.parse(json['slot_date'] as String),
      slotStart: DateTime.parse(json['slot_start'] as String),
      slotEnd: DateTime.parse(json['slot_end'] as String),
      isLocked: json['is_locked'] as bool? ?? false,
      lockedUntil: json['locked_until'] != null
          ? DateTime.tryParse(json['locked_until'] as String)
          : null,
      status: json['status'] as String? ?? 'available',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'doctor_id': doctorId,
      'slot_date': slotDate.toIso8601String().split('T')[0],
      'slot_start': slotStart.toIso8601String(),
      'slot_end': slotEnd.toIso8601String(),
      'is_locked': isLocked,
      'locked_until': lockedUntil?.toIso8601String(),
      'status': status,
    };
  }
}
