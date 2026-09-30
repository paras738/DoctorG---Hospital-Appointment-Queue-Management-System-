import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../controllers/doctor_directory_controller.dart';
import '../widgets/doctor_card.dart';
import '../widgets/symptom_carousel.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/city_selector_sheet.dart';

class DoctorDirectoryScreen extends ConsumerStatefulWidget {
  const DoctorDirectoryScreen({super.key});

  @override
  ConsumerState<DoctorDirectoryScreen> createState() =>
      _DoctorDirectoryScreenState();
}

class _DoctorDirectoryScreenState extends ConsumerState<DoctorDirectoryScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      ref.read(doctorDirectoryControllerProvider.notifier).loadNextPage();
    }
  }

  void _openCitySelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const CitySelectorSheet(),
    );
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const FilterBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentCity = ref.watch(selectedCityProvider);
    final activeFilter = ref.watch(doctorFilterProvider);
    final state = ref.watch(doctorDirectoryControllerProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: InkWell(
          onTap: _openCitySelector,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on,
                  color: AppTheme.primaryTeal,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  currentCity,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 20,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Filters',
            onPressed: _openFilterSheet,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(doctorDirectoryControllerProvider.notifier).refresh(),
        color: AppTheme.primaryTeal,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Search Bar Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search symptom (e.g. chest pain) or doctor',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppTheme.primaryTeal,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              ref
                                      .read(doctorSearchQueryProvider.notifier)
                                      .state =
                                  '';
                              ref
                                  .read(
                                    doctorDirectoryControllerProvider.notifier,
                                  )
                                  .refresh();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                  ),
                  onSubmitted: (query) {
                    ref.read(doctorSearchQueryProvider.notifier).state = query;
                    ref
                        .read(doctorDirectoryControllerProvider.notifier)
                        .refresh();
                  },
                ),
              ),
            ),

            // Popular Symptom Carousel
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: SymptomCarousel(),
              ),
            ),

            // Active Filters Summary Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: _openFilterSheet,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: activeFilter.hasActiveFilters
                              ? AppTheme.primaryLightTeal
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: activeFilter.hasActiveFilters
                                ? AppTheme.primaryTeal
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.filter_list,
                              size: 14,
                              color: activeFilter.hasActiveFilters
                                  ? AppTheme.primaryDarkTeal
                                  : Colors.black87,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              activeFilter.hasActiveFilters
                                  ? '${activeFilter.activeFilterCount} Filters'
                                  : 'Filter',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: activeFilter.hasActiveFilters
                                    ? AppTheme.primaryDarkTeal
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Quick "Available Now" toggle
                    FilterChip(
                      label: const Text(
                        'Available Now',
                        style: TextStyle(fontSize: 12),
                      ),
                      selected: activeFilter.availableNow,
                      selectedColor: AppTheme.primaryLightTeal,
                      onSelected: (val) {
                        ref.read(doctorFilterProvider.notifier).state =
                            activeFilter.copyWith(availableNow: val);
                        ref
                            .read(doctorDirectoryControllerProvider.notifier)
                            .refresh();
                      },
                    ),
                    const SizedBox(width: 8),

                    // Quick "Available Today" toggle
                    FilterChip(
                      label: const Text(
                        'Available Today',
                        style: TextStyle(fontSize: 12),
                      ),
                      selected: activeFilter.availableToday,
                      selectedColor: AppTheme.primaryLightTeal,
                      onSelected: (val) {
                        ref.read(doctorFilterProvider.notifier).state =
                            activeFilter.copyWith(availableToday: val);
                        ref
                            .read(doctorDirectoryControllerProvider.notifier)
                            .refresh();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 6)),

            // Doctor List Content
            if (state.isLoading && state.doctors.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryTeal),
                ),
              )
            else if (state.error != null && state.doctors.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.wifi_off_rounded,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Could not load doctors',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          state.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => ref
                              .read(doctorDirectoryControllerProvider.notifier)
                              .refresh(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (state.doctors.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 56,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No doctors found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Try clearing some filters or searching a different symptom.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final doctor = state.doctors[index];
                  return DoctorCard(
                    doctor: doctor,
                    onTap: () => context.push('/doctor/${doctor.id}'),
                    onBook: () => context.push('/doctor/${doctor.id}'),
                  );
                }, childCount: state.doctors.length),
              ),

              // Pagination Loading Indicator
              if (state.isFetchingNextPage)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryTeal,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ],
        ),
      ),
    );
  }
}
