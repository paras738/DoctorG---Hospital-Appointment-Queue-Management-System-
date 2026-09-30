class DoctorModel {
  final String id;
  final String fullName;
  final String registrationNumber;
  final String specialization;
  final int experienceYears;
  final double consultationFee;
  final List<String> languages;
  final String? photoUrl;
  final String? bio;
  final bool isVerified;
  final bool isAvailableToday;
  final bool isAvailableNow;
  final int avgConsultationMinutes;
  final int reviewCount;
  final double avgRating;
  final double bayesianScore;
  final bool isTopRated;
  final String? hospitalName;
  final String? hospitalAddress;
  final double? hospitalLat;
  final double? hospitalLng;
  final double? distanceMeters;
  final DateTime? nextAvailableSlot;

  const DoctorModel({
    required this.id,
    required this.fullName,
    required this.registrationNumber,
    required this.specialization,
    required this.experienceYears,
    required this.consultationFee,
    required this.languages,
    this.photoUrl,
    this.bio,
    required this.isVerified,
    required this.isAvailableToday,
    required this.isAvailableNow,
    required this.avgConsultationMinutes,
    required this.reviewCount,
    required this.avgRating,
    required this.bayesianScore,
    required this.isTopRated,
    this.hospitalName,
    this.hospitalAddress,
    this.hospitalLat,
    this.hospitalLng,
    this.distanceMeters,
    this.nextAvailableSlot,
  });

  factory DoctorModel.fromJson(
    Map<String, dynamic> json, {
    double? userLat,
    double? userLng,
  }) {
    double? hospLat;
    double? hospLng;
    double? distMeters = json['distance_meters'] != null
        ? (json['distance_meters'] as num).toDouble()
        : null;

    if (json['hospitals'] != null && json['hospitals'] is Map) {
      final hosp = json['hospitals'] as Map<String, dynamic>;
      if (hosp['latitude'] != null && hosp['longitude'] != null) {
        hospLat = (hosp['latitude'] as num).toDouble();
        hospLng = (hosp['longitude'] as num).toDouble();
      }
    }

    return DoctorModel(
      id: json['doctor_id'] as String? ?? json['id'] as String,
      fullName: json['full_name'] as String? ?? 'Dr. Unknown',
      registrationNumber: json['registration_number'] as String? ?? '',
      specialization: json['specialization'] as String? ?? 'General Physician',
      experienceYears: (json['experience_years'] as num?)?.toInt() ?? 0,
      consultationFee: (json['consultation_fee'] as num?)?.toDouble() ?? 500.0,
      languages: json['languages'] != null
          ? List<String>.from(json['languages'] as List)
          : ['English', 'Hindi'],
      photoUrl: json['photo_url'] as String?,
      bio: json['bio'] as String?,
      isVerified: json['is_verified'] as bool? ?? true,
      isAvailableToday: json['is_available_today'] as bool? ?? true,
      isAvailableNow: json['is_available_now'] as bool? ?? false,
      avgConsultationMinutes:
          (json['avg_consultation_minutes'] as num?)?.toInt() ?? 15,
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      avgRating: (json['avg_rating'] as num?)?.toDouble() ?? 0.0,
      bayesianScore: (json['bayesian_score'] as num?)?.toDouble() ?? 0.0,
      isTopRated: json['is_top_rated'] as bool? ?? false,
      hospitalName: json['hospital_name'] as String?,
      hospitalAddress: json['hospital_address'] as String?,
      hospitalLat: hospLat,
      hospitalLng: hospLng,
      distanceMeters: distMeters,
      nextAvailableSlot: json['next_slot'] != null
          ? DateTime.tryParse(json['next_slot'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'doctor_id': id,
      'full_name': fullName,
      'registration_number': registrationNumber,
      'specialization': specialization,
      'experience_years': experienceYears,
      'consultation_fee': consultationFee,
      'languages': languages,
      'photo_url': photoUrl,
      'bio': bio,
      'is_verified': isVerified,
      'is_available_today': isAvailableToday,
      'is_available_now': isAvailableNow,
      'avg_consultation_minutes': avgConsultationMinutes,
      'review_count': reviewCount,
      'avg_rating': avgRating,
      'bayesian_score': bayesianScore,
      'is_top_rated': isTopRated,
      'hospital_name': hospitalName,
      'hospital_address': hospitalAddress,
      'distance_meters': distanceMeters,
      'next_slot': nextAvailableSlot?.toIso8601String(),
    };
  }

  DoctorModel copyWith({
    double? distanceMeters,
    DateTime? nextAvailableSlot,
    String? hospitalName,
    String? hospitalAddress,
  }) {
    return DoctorModel(
      id: id,
      fullName: fullName,
      registrationNumber: registrationNumber,
      specialization: specialization,
      experienceYears: experienceYears,
      consultationFee: consultationFee,
      languages: languages,
      photoUrl: photoUrl,
      bio: bio,
      isVerified: isVerified,
      isAvailableToday: isAvailableToday,
      isAvailableNow: isAvailableNow,
      avgConsultationMinutes: avgConsultationMinutes,
      reviewCount: reviewCount,
      avgRating: avgRating,
      bayesianScore: bayesianScore,
      isTopRated: isTopRated,
      hospitalName: hospitalName ?? this.hospitalName,
      hospitalAddress: hospitalAddress ?? this.hospitalAddress,
      hospitalLat: hospitalLat,
      hospitalLng: hospitalLng,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      nextAvailableSlot: nextAvailableSlot ?? this.nextAvailableSlot,
    );
  }
}
