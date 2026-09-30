import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/doctor_directory/presentation/screens/doctor_directory_screen.dart';
import '../../../features/hospitals_map/presentation/screens/hospitals_map_screen.dart';
import '../../../features/auth/presentation/controllers/auth_controller.dart';

import '../../../features/booking/presentation/screens/my_appointments_screen.dart';

final homeNavIndexProvider = StateProvider<int>((ref) => 0);

class PatientHomeScreen extends ConsumerWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(homeNavIndexProvider);

    final pages = [
      const DoctorDirectoryScreen(),
      const HospitalsMapScreen(),
      const MyAppointmentsScreen(),
      const _ProfileTabPlaceholder(),
    ];

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (idx) {
          ref.read(homeNavIndexProvider.notifier).state = idx;
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search_rounded),
            selectedIcon: Icon(
              Icons.search_rounded,
              color: AppTheme.primaryTeal,
            ),
            label: 'Find Doctors',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded, color: AppTheme.primaryTeal),
            label: 'Hospitals Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            selectedIcon: Icon(
              Icons.confirmation_number,
              color: AppTheme.primaryTeal,
            ),
            label: 'My Tokens',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppTheme.primaryTeal),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ProfileTabPlaceholder extends ConsumerWidget {
  const _ProfileTabPlaceholder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 32,
                backgroundColor: AppTheme.primaryLightTeal,
                child: Icon(
                  Icons.person,
                  size: 36,
                  color: AppTheme.primaryTeal,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName.isNotEmpty == true
                          ? user!.fullName
                          : 'Patient User',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      user?.email ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          ListTile(
            leading: const Icon(
              Icons.family_restroom,
              color: AppTheme.secondaryBlue,
            ),
            title: const Text('Saved Family Members'),
            subtitle: const Text(
              'Manage family profiles for fast appointment booking',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(
              Icons.notifications_outlined,
              color: AppTheme.secondaryBlue,
            ),
            title: const Text('Notification Preferences'),
            subtitle: const Text('Queue arrival warnings, slot openings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(
              Icons.security_outlined,
              color: AppTheme.secondaryBlue,
            ),
            title: const Text('Privacy & Data (India DPDP Act)'),
            subtitle: const Text('View and manage your consented medical data'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
    );
  }
}
