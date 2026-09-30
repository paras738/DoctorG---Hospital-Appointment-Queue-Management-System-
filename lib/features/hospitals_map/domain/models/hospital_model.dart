enum HospitalStatus {
  openNow,
  busyQueue,
  closed;

  String get label {
    switch (this) {
      case HospitalStatus.openNow:
        return 'Doctors Available Now';
      case HospitalStatus.busyQueue:
        return 'High OPD Queue';
      case HospitalStatus.closed:
        return 'Closed';
    }
  }
}

class HospitalModel {
  final String id;
  final String name;
  final String address;
  final String city;
  final String pincode;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final bool emergencyAvailable;
  final int doctorsTodayCount;
  final double rating;
  final HospitalStatus status;
  final String phone;

  const HospitalModel({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.pincode,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.emergencyAvailable,
    required this.doctorsTodayCount,
    this.rating = 4.6,
    this.status = HospitalStatus.openNow,
    this.phone = '+91 80 2502 4444',
  });

  factory HospitalModel.fromJson(Map<String, dynamic> json) {
    HospitalStatus stat = HospitalStatus.openNow;
    final docCount = (json['doctors_today_count'] as num?)?.toInt() ?? 1;
    if (docCount == 0) {
      stat = HospitalStatus.closed;
    } else if (docCount > 4) {
      stat = HospitalStatus.busyQueue;
    }

    return HospitalModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Clinic / Hospital',
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? 'Bengaluru',
      pincode: json['pincode'] as String? ?? '560001',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 12.9592,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 77.6517,
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0.0,
      emergencyAvailable: json['emergency_available'] as bool? ?? true,
      doctorsTodayCount: docCount,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.7,
      status: stat,
      phone: json['phone'] as String? ?? '+91 80 4199 4444',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'pincode': pincode,
      'latitude': latitude,
      'longitude': longitude,
      'distance_meters': distanceMeters,
      'emergency_available': emergencyAvailable,
      'doctors_today_count': doctorsTodayCount,
      'rating': rating,
      'phone': phone,
    };
  }
}

class HospitalRouteModel {
  final double roadDistanceMeters;
  final String roadDistanceText;
  final int durationMinutes;
  final String durationText;
  final List<List<double>> polylinePoints; // [[lat, lng], ...]
  final DateTime cachedAt;

  const HospitalRouteModel({
    required this.roadDistanceMeters,
    required this.roadDistanceText,
    required this.durationMinutes,
    required this.durationText,
    required this.polylinePoints,
    required this.cachedAt,
  });

  factory HospitalRouteModel.fromJson(Map<String, dynamic> json) {
    return HospitalRouteModel(
      roadDistanceMeters: (json['road_distance_meters'] as num).toDouble(),
      roadDistanceText: json['road_distance_text'] as String,
      durationMinutes: (json['duration_minutes'] as num).toInt(),
      durationText: json['duration_text'] as String,
      polylinePoints: (json['polyline_points'] as List)
          .map((pt) => (pt as List).map((n) => (n as num).toDouble()).toList())
          .toList(),
      cachedAt: DateTime.parse(json['cached_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'road_distance_meters': roadDistanceMeters,
      'road_distance_text': roadDistanceText,
      'duration_minutes': durationMinutes,
      'duration_text': durationText,
      'polyline_points': polylinePoints,
      'cached_at': cachedAt.toIso8601String(),
    };
  }
}
