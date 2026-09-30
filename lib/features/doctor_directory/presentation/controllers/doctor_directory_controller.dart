import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/doctor_model.dart';
import '../../domain/models/doctor_filter.dart';
import '../../domain/models/doctor_review_model.dart';
import '../../data/repositories/supabase_doctor_repository.dart';

final selectedCityProvider = StateProvider<String>((ref) => 'Bengaluru');

final doctorFilterProvider = StateProvider<DoctorFilter>(
  (ref) => const DoctorFilter(),
);

final doctorSearchQueryProvider = StateProvider<String>((ref) => '');

final userLocationProvider = StateProvider<Map<String, double>?>((ref) => null);

final specializationsProvider = FutureProvider<List<String>>((ref) {
  final repo = ref.watch(doctorRepositoryProvider);
  return repo.getSpecializations();
});

final popularSymptomsProvider = FutureProvider<List<Map<String, String>>>((
  ref,
) {
  final repo = ref.watch(doctorRepositoryProvider);
  return repo.getPopularSymptoms();
});

final doctorProfileProvider = FutureProvider.family<DoctorModel?, String>((
  ref,
  doctorId,
) async {
  final repo = ref.watch(doctorRepositoryProvider);
  final loc = ref.watch(userLocationProvider);
  return repo.getDoctorById(
    doctorId,
    userLat: loc?['lat'],
    userLng: loc?['lng'],
  );
});

final doctorReviewsProvider =
    FutureProvider.family<List<DoctorReviewModel>, String>((ref, doctorId) {
      final repo = ref.watch(doctorRepositoryProvider);
      return repo.getDoctorReviews(doctorId);
    });

class DoctorDirectoryState {
  final List<DoctorModel> doctors;
  final bool isLoading;
  final bool isFetchingNextPage;
  final bool hasMore;
  final int page;
  final String? error;

  const DoctorDirectoryState({
    this.doctors = const [],
    this.isLoading = false,
    this.isFetchingNextPage = false,
    this.hasMore = true,
    this.page = 0,
    this.error,
  });

  DoctorDirectoryState copyWith({
    List<DoctorModel>? doctors,
    bool? isLoading,
    bool? isFetchingNextPage,
    bool? hasMore,
    int? page,
    String? error,
  }) {
    return DoctorDirectoryState(
      doctors: doctors ?? this.doctors,
      isLoading: isLoading ?? this.isLoading,
      isFetchingNextPage: isFetchingNextPage ?? this.isFetchingNextPage,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      error: error,
    );
  }
}

final doctorDirectoryControllerProvider =
    StateNotifierProvider<DoctorDirectoryController, DoctorDirectoryState>((
      ref,
    ) {
      final repo = ref.watch(doctorRepositoryProvider);
      final city = ref.watch(selectedCityProvider);
      final filter = ref.watch(doctorFilterProvider);
      final query = ref.watch(doctorSearchQueryProvider);
      final loc = ref.watch(userLocationProvider);

      return DoctorDirectoryController(
        repo: repo,
        city: city,
        filter: filter,
        searchQuery: query,
        userLat: loc?['lat'],
        userLng: loc?['lng'],
      );
    });

class DoctorDirectoryController extends StateNotifier<DoctorDirectoryState> {
  final SupabaseDoctorRepository repo;
  final String city;
  final DoctorFilter filter;
  final String searchQuery;
  final double? userLat;
  final double? userLng;

  static const int pageSize = 20;

  DoctorDirectoryController({
    required this.repo,
    required this.city,
    required this.filter,
    required this.searchQuery,
    this.userLat,
    this.userLng,
  }) : super(const DoctorDirectoryState()) {
    loadFirstPage();
  }

  Future<void> loadFirstPage() async {
    state = state.copyWith(isLoading: true, error: null, page: 0);
    try {
      final list = await repo.getDoctors(
        city: city,
        searchQuery: searchQuery.isEmpty ? null : searchQuery,
        filter: filter,
        page: 0,
        pageSize: pageSize,
        userLat: userLat,
        userLng: userLng,
      );
      state = state.copyWith(
        doctors: list,
        isLoading: false,
        hasMore: list.length == pageSize,
        page: 0,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadNextPage() async {
    if (state.isLoading || state.isFetchingNextPage || !state.hasMore) return;

    final nextPage = state.page + 1;
    state = state.copyWith(isFetchingNextPage: true);

    try {
      final nextList = await repo.getDoctors(
        city: city,
        searchQuery: searchQuery.isEmpty ? null : searchQuery,
        filter: filter,
        page: nextPage,
        pageSize: pageSize,
        userLat: userLat,
        userLng: userLng,
      );

      state = state.copyWith(
        doctors: [...state.doctors, ...nextList],
        isFetchingNextPage: false,
        hasMore: nextList.length == pageSize,
        page: nextPage,
      );
    } catch (e) {
      state = state.copyWith(isFetchingNextPage: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await loadFirstPage();
  }
}
