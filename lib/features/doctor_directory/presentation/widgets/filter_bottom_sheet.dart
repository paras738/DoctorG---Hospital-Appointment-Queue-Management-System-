import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/doctor_filter.dart';
import '../controllers/doctor_directory_controller.dart';

class FilterBottomSheet extends ConsumerStatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> {
  late DoctorFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = ref.read(doctorFilterProvider);
  }

  @override
  Widget build(BuildContext context) {
    final specializationsAsync = ref.watch(specializationsProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Filters & Sort',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (_filter.hasActiveFilters) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLightTeal,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_filter.activeFilterCount} active',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryDarkTeal,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              TextButton(
                onPressed: () => setState(() => _filter = const DoctorFilter()),
                child: const Text('Reset All'),
              ),
            ],
          ),
          const Divider(),

          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sort By
                  const Text(
                    'Sort By',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: DoctorSortBy.values.map((sort) {
                      final isSelected = _filter.sortBy == sort;
                      return ChoiceChip(
                        label: Text(sort.label),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryLightTeal,
                        onSelected: (val) {
                          if (val)
                            setState(
                              () => _filter = _filter.copyWith(sortBy: sort),
                            );
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Quick Availability Toggles
                  const Text(
                    'Availability',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Available Today'),
                    value: _filter.availableToday,
                    activeColor: AppTheme.primaryTeal,
                    onChanged: (val) => setState(
                      () => _filter = _filter.copyWith(availableToday: val),
                    ),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Available Right Now (Live Queue On)'),
                    value: _filter.availableNow,
                    activeColor: AppTheme.primaryTeal,
                    onChanged: (val) => setState(
                      () => _filter = _filter.copyWith(availableNow: val),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Consultation Fee Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Max Consultation Fee',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '₹${_filter.maxFee.round()}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryTeal,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _filter.maxFee,
                    min: 200,
                    max: 2500,
                    divisions: 23,
                    activeColor: AppTheme.primaryTeal,
                    label: '₹${_filter.maxFee.round()}',
                    onChanged: (val) =>
                        setState(() => _filter = _filter.copyWith(maxFee: val)),
                  ),
                  const SizedBox(height: 12),

                  // Specializations Chips
                  const Text(
                    'Specialization',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  specializationsAsync.when(
                    data: (specs) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: specs.map((spec) {
                        final isSelected = _filter.specialization == spec;
                        return FilterChip(
                          label: Text(spec),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryLightTeal,
                          checkmarkColor: AppTheme.primaryDarkTeal,
                          onSelected: (val) {
                            setState(() {
                              _filter = _filter.copyWith(
                                specialization: val ? spec : null,
                                clearSpecialization: !val,
                              );
                            });
                          },
                        );
                      }).toList(),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) =>
                        const Text('Could not load specializations'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Apply Button
          FilledButton(
            onPressed: () {
              ref.read(doctorFilterProvider.notifier).state = _filter;
              ref.read(doctorDirectoryControllerProvider.notifier).refresh();
              Navigator.pop(context);
            },
            child: const Text('Apply Filters'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
