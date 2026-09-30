import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/theme/app_theme.dart';
import '../controllers/doctor_directory_controller.dart';

class CitySelectorSheet extends ConsumerStatefulWidget {
  const CitySelectorSheet({super.key});

  @override
  ConsumerState<CitySelectorSheet> createState() => _CitySelectorSheetState();
}

class _CitySelectorSheetState extends ConsumerState<CitySelectorSheet> {
  bool _isDetecting = false;

  final List<String> _cities = [
    'Bengaluru',
    'Delhi-NCR',
    'Mumbai',
    'Hyderabad',
    'Chennai',
    'Pune',
    'Kolkata',
  ];

  Future<void> _detectLocation() async {
    setState(() => _isDetecting = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission denied. Please select city manually.',
              ),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      if (mounted) {
        ref.read(userLocationProvider.notifier).state = {
          'lat': position.latitude,
          'lng': position.longitude,
        };
        // Auto-refresh directory with coordinates
        ref.read(doctorDirectoryControllerProvider.notifier).refresh();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not detect location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDetecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentCity = ref.watch(selectedCityProvider);

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Your City',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Detect Live Location Button
          OutlinedButton.icon(
            icon: _isDetecting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location, color: AppTheme.primaryTeal),
            label: const Text('Use Current GPS Location'),
            onPressed: _isDetecting ? null : _detectLocation,
          ),
          const SizedBox(height: 16),
          const Divider(),

          // List of Supported Indian Cities
          ..._cities.map((city) {
            final isSelected = city == currentCity;
            return ListTile(
              leading: Icon(
                Icons.location_city,
                color: isSelected ? AppTheme.primaryTeal : Colors.grey.shade500,
              ),
              title: Text(
                city,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.primaryDarkTeal : Colors.black87,
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_circle, color: AppTheme.primaryTeal)
                  : null,
              onTap: () {
                ref.read(selectedCityProvider.notifier).state = city;
                ref.read(doctorDirectoryControllerProvider.notifier).refresh();
                Navigator.pop(context);
              },
            );
          }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
