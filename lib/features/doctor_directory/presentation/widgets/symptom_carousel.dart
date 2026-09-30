import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../controllers/doctor_directory_controller.dart';

class SymptomCarousel extends ConsumerWidget {
  const SymptomCarousel({super.key});

  IconData _getSymptomIcon(String? iconKey) {
    switch (iconKey) {
      case 'favorite':
        return Icons.favorite_border;
      case 'healing':
        return Icons.healing;
      case 'thermostat':
        return Icons.thermostat;
      case 'child_care':
        return Icons.child_care;
      case 'accessibility':
        return Icons.accessibility_new;
      case 'sentiment_satisfied':
        return Icons.sentiment_satisfied_alt;
      case 'hearing':
        return Icons.hearing;
      case 'psychology':
        return Icons.psychology;
      default:
        return Icons.medical_services_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final symptomsAsync = ref.watch(popularSymptomsProvider);
    final activeFilter = ref.watch(doctorFilterProvider);

    return symptomsAsync.when(
      data: (symptoms) {
        return SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: symptoms.length,
            itemBuilder: (context, index) {
              final item = symptoms[index];
              final symptomName = item['symptom']!;
              final spec = item['specialization']!;
              final isSelected = activeFilter.specialization == spec;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  avatar: Icon(
                    _getSymptomIcon(item['icon']),
                    size: 16,
                    color: isSelected
                        ? AppTheme.primaryDarkTeal
                        : AppTheme.secondaryBlue,
                  ),
                  label: Text(symptomName),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? AppTheme.primaryDarkTeal
                        : Colors.black87,
                  ),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryLightTeal,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? AppTheme.primaryTeal
                          : Colors.grey.shade300,
                    ),
                  ),
                  onSelected: (selected) {
                    final newFilter = activeFilter.copyWith(
                      specialization: selected ? spec : null,
                      clearSpecialization: !selected,
                    );
                    ref.read(doctorFilterProvider.notifier).state = newFilter;
                    ref
                        .read(doctorDirectoryControllerProvider.notifier)
                        .refresh();
                  },
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(height: 48),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
