enum DoctorSortBy {
  bayesianRating,
  distanceNearest,
  feeLowToHigh,
  feeHighToLow,
  experienceHigh;

  String get label {
    switch (this) {
      case DoctorSortBy.bayesianRating:
        return 'Top Ranked (Bayesian)';
      case DoctorSortBy.distanceNearest:
        return 'Nearest First';
      case DoctorSortBy.feeLowToHigh:
        return 'Fee: Low to High';
      case DoctorSortBy.feeHighToLow:
        return 'Fee: High to Low';
      case DoctorSortBy.experienceHigh:
        return 'Experience: High to Low';
    }
  }
}

class DoctorFilter {
  final String? specialization;
  final double minFee;
  final double maxFee;
  final double? maxDistanceKm;
  final String? language;
  final String? gender;
  final bool availableToday;
  final bool availableNow;
  final String consultationType; // 'all', 'clinic', 'video'
  final DoctorSortBy sortBy;

  const DoctorFilter({
    this.specialization,
    this.minFee = 0,
    this.maxFee = 2500,
    this.maxDistanceKm,
    this.language,
    this.gender,
    this.availableToday = false,
    this.availableNow = false,
    this.consultationType = 'all',
    this.sortBy = DoctorSortBy.bayesianRating,
  });

  bool get hasActiveFilters =>
      specialization != null ||
      minFee > 0 ||
      maxFee < 2500 ||
      maxDistanceKm != null ||
      language != null ||
      gender != null ||
      availableToday ||
      availableNow ||
      consultationType != 'all' ||
      sortBy != DoctorSortBy.bayesianRating;

  int get activeFilterCount {
    int count = 0;
    if (specialization != null) count++;
    if (minFee > 0 || maxFee < 2500) count++;
    if (maxDistanceKm != null) count++;
    if (language != null) count++;
    if (gender != null) count++;
    if (availableToday) count++;
    if (availableNow) count++;
    if (consultationType != 'all') count++;
    if (sortBy != DoctorSortBy.bayesianRating) count++;
    return count;
  }

  DoctorFilter copyWith({
    String? specialization,
    bool clearSpecialization = false,
    double? minFee,
    double? maxFee,
    double? maxDistanceKm,
    bool clearDistance = false,
    String? language,
    bool clearLanguage = false,
    String? gender,
    bool clearGender = false,
    bool? availableToday,
    bool? availableNow,
    String? consultationType,
    DoctorSortBy? sortBy,
  }) {
    return DoctorFilter(
      specialization: clearSpecialization
          ? null
          : (specialization ?? this.specialization),
      minFee: minFee ?? this.minFee,
      maxFee: maxFee ?? this.maxFee,
      maxDistanceKm: clearDistance
          ? null
          : (maxDistanceKm ?? this.maxDistanceKm),
      language: clearLanguage ? null : (language ?? this.language),
      gender: clearGender ? null : (gender ?? this.gender),
      availableToday: availableToday ?? this.availableToday,
      availableNow: availableNow ?? this.availableNow,
      consultationType: consultationType ?? this.consultationType,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  DoctorFilter reset() {
    return const DoctorFilter();
  }
}
