import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/hospital_model.dart';
import '../controllers/hospitals_map_controller.dart';
import '../../../doctor_directory/presentation/controllers/doctor_directory_controller.dart';

class HospitalDetailSheet extends ConsumerWidget {
  final HospitalModel hospital;
  final VoidCallback onGetDirections;

  const HospitalDetailSheet({
    super.key,
    required this.hospital,
    required this.onGetDirections,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeAsync = ref.watch(hospitalRouteProvider(hospital));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title Row: Name + Close
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hospital.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hospital.address,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Road Distance & ETA Banner (On-Demand Cached Route)
          routeAsync.when(
            data: (route) => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryLightTeal,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryTeal.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.directions_car,
                    color: AppTheme.primaryDarkTeal,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${route.roadDistanceText} • ${route.durationText} drive',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryDarkTeal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Route refreshed on-demand with traffic estimate',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            loading: () =>
                const LinearProgressIndicator(color: AppTheme.primaryTeal),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 14),

          // "Time to Leave" Alert Banner (Combining Live Queue + Road Travel Time)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.alarm, color: Color(0xFFE65100), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                      children: [
                        TextSpan(
                          text: 'Time to Leave Alert: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE65100),
                          ),
                        ),
                        TextSpan(
                          text: '3 patients ahead in queue (~35 min wait). With 18 min drive time, you should leave your home within 15 minutes!',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Action Buttons Grid
          Row(
            children: [
              // In-App Directions
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.directions, size: 18),
                  label: const Text('Directions'),
                  onPressed: () {
                    Navigator.pop(context);
                    onGetDirections();
                  },
                ),
              ),
              const SizedBox(width: 10),

              // Call Clinic
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.phone, size: 18),
                  label: const Text('Call Clinic'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Calling clinic at ${hospital.phone}'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Filter Doctors at this Hospital Button
          TextButton.icon(
            icon: const Icon(Icons.person_search_outlined, size: 18),
            label: const Text('View Available Doctors at this Hospital'),
            onPressed: () {
              Navigator.pop(context);
              ref.read(doctorSearchQueryProvider.notifier).state =
                  hospital.name;
              ref.read(doctorDirectoryControllerProvider.notifier).refresh();
            },
          ),
        ],
      ),
    );
  }
}
