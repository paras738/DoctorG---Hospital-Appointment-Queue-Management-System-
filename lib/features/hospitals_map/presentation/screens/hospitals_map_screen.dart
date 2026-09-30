import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/hospital_model.dart';
import '../controllers/hospitals_map_controller.dart';
import '../widgets/hospital_card.dart';
import '../widgets/hospital_detail_sheet.dart';
import '../../../doctor_directory/presentation/controllers/doctor_directory_controller.dart';

class HospitalsMapScreen extends ConsumerStatefulWidget {
  const HospitalsMapScreen({super.key});

  @override
  ConsumerState<HospitalsMapScreen> createState() => _HospitalsMapScreenState();
}

class _HospitalsMapScreenState extends ConsumerState<HospitalsMapScreen> {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};

  final List<Map<String, dynamic>> _radiusOptions = [
    {'label': '2 km', 'meters': 2000.0},
    {'label': '5 km', 'meters': 5000.0},
    {'label': '10 km', 'meters': 10000.0},
    {'label': 'Whole City', 'meters': 50000.0},
  ];

  void _showHospitalDetail(HospitalModel hospital) {
    ref.read(selectedHospitalProvider.notifier).state = hospital;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => HospitalDetailSheet(
        hospital: hospital,
        onGetDirections: () => _drawRoute(hospital),
      ),
    );
  }

  Future<void> _drawRoute(HospitalModel hospital) async {
    final route = await ref.read(hospitalRouteProvider(hospital).future);
    final pts = route.polylinePoints.map((p) => LatLng(p[0], p[1])).toList();

    setState(() {
      _polylines = {
        Polyline(
          polylineId: PolylineId('route_${hospital.id}'),
          points: pts,
          color: AppTheme.primaryTeal,
          width: 5,
        ),
      };
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            pts.map((p) => p.latitude).reduce((a, b) => a < b ? a : b),
            pts.map((p) => p.longitude).reduce((a, b) => a < b ? a : b),
          ),
          northeast: LatLng(
            pts.map((p) => p.latitude).reduce((a, b) => a > b ? a : b),
            pts.map((p) => p.longitude).reduce((a, b) => a > b ? a : b),
          ),
        ),
        60,
      ),
    );
  }

  Set<Marker> _buildMarkers(List<HospitalModel> hospitals) {
    return hospitals.map((h) {
      double hue = BitmapDescriptor.hueGreen;
      if (h.status == HospitalStatus.busyQueue) {
        hue = BitmapDescriptor.hueOrange;
      } else if (h.status == HospitalStatus.closed) {
        hue = BitmapDescriptor.hueViolet;
      }

      return Marker(
        markerId: MarkerId(h.id),
        position: LatLng(h.latitude, h.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(
          title: h.name,
          snippet: '${h.status.label} • ${h.doctorsTodayCount} doctors',
          onTap: () => _showHospitalDetail(h),
        ),
        onTap: () => _showHospitalDetail(h),
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final viewMode = ref.watch(hospitalViewModeProvider);
    final currentRadius = ref.watch(hospitalRadiusMetersProvider);
    final hospitalsAsync = ref.watch(nearbyHospitalsProvider);
    final userLoc = ref.watch(userLocationProvider);

    final defaultLat = userLoc?['lat'] ?? 12.9716;
    final defaultLng = userLoc?['lng'] ?? 77.5946;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Hospitals & Clinics'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.white,
            child: Row(
              children: [
                // View Mode Toggle (List | Map)
                SegmentedButton<HospitalViewMode>(
                  segments: const [
                    ButtonSegment(
                      value: HospitalViewMode.map,
                      label: Text('Map'),
                      icon: Icon(Icons.map_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: HospitalViewMode.list,
                      label: Text('List'),
                      icon: Icon(Icons.list_alt_rounded, size: 16),
                    ),
                  ],
                  selected: {viewMode},
                  onSelectionChanged: (val) {
                    ref.read(hospitalViewModeProvider.notifier).state =
                        val.first;
                  },
                ),
                const SizedBox(width: 12),

                // Radius Dropdown
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _radiusOptions.map((opt) {
                        final isSelected = currentRadius == opt['meters'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              opt['label'],
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: isSelected,
                            selectedColor: AppTheme.primaryLightTeal,
                            onSelected: (val) {
                              if (val) {
                                ref
                                        .read(
                                          hospitalRadiusMetersProvider.notifier,
                                        )
                                        .state =
                                    opt['meters'] as double;
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: hospitalsAsync.when(
        data: (hospitals) {
          if (viewMode == HospitalViewMode.list) {
            return RefreshIndicator(
              onRefresh: () async => ref.refresh(nearbyHospitalsProvider),
              color: AppTheme.primaryTeal,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: hospitals.length,
                itemBuilder: (context, index) {
                  final hospital = hospitals[index];
                  return HospitalCard(
                    hospital: hospital,
                    onTap: () => _showHospitalDetail(hospital),
                  );
                },
              ),
            );
          }

          // Map View with color-coded status pins and live location
          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(defaultLat, defaultLng),
                  zoom: 12.5,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                compassEnabled: true,
                markers: _buildMarkers(hospitals),
                polylines: _polylines,
                onMapCreated: (ctrl) => _mapController = ctrl,
              ),

              // Legend Pill (Green = Open, Orange = High Queue)
              Positioned(
                top: 12,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 4),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLegendDot(
                        AppTheme.successGreen,
                        'Doctors Available',
                      ),
                      const SizedBox(width: 8),
                      _buildLegendDot(AppTheme.accentAmber, 'High Queue'),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryTeal),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.location_off_rounded,
                size: 48,
                color: Colors.grey,
              ),
              const SizedBox(height: 12),
              const Text(
                'Could not load nearby hospitals',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                err.toString(),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.refresh(nearbyHospitalsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
