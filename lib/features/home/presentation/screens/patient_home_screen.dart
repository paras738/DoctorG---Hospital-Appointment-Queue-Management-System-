import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/localization/locale_controller.dart';
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

          // Language Switcher (English / हिंदी)
          Consumer(
            builder: (context, ref, _) {
              final locale = ref.watch(localeProvider);
              final isHindi = locale.languageCode == 'hi';

              return ListTile(
                leading: const Icon(
                  Icons.translate_rounded,
                  color: AppTheme.primaryTeal,
                ),
                title: const Text('Language / भाषा'),
                subtitle: Text(
                  isHindi ? 'वर्तमान भाषा: हिंदी (Hindi)' : 'Current: English',
                ),
                trailing: Switch(
                  value: isHindi,
                  activeColor: AppTheme.primaryTeal,
                  onChanged: (_) {
                    ref.read(localeProvider.notifier).toggleLanguage();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 2),
                        content: Text(
                          isHindi
                              ? 'App language switched to English'
                              : 'ऐप की भाषा हिंदी में बदल दी गई है',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(
              Icons.notifications_outlined,
              color: AppTheme.secondaryBlue,
            ),
            title: const Text('Notifications & Alerts'),
            subtitle: const Text('View arrival warnings, OPD delay notices'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/notifications'),
          ),

          ListTile(
            leading: const Icon(
              Icons.admin_panel_settings_outlined,
              color: AppTheme.accentAmber,
            ),
            title: const Text('Admin Verification Panel'),
            subtitle: const Text('Doctor approvals & review moderation'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/admin'),
          ),

          ListTile(
            leading: const Icon(
              Icons.medical_services_outlined,
              color: AppTheme.primaryTeal,
            ),
            title: const Text('Doctor OPD Console'),
            subtitle: const Text('Switch to clinic queue management dashboard'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/doctor-dashboard'),
          ),

          ListTile(
            leading: const Icon(
              Icons.security_outlined,
              color: Colors.blueGrey,
            ),
            title: const Text('Privacy & Consent (DPDP Act India)'),
            subtitle: const Text('View and manage your consented medical data'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'DoctorG complies with India Digital Personal Data Protection (DPDP) Act.',
                  ),
                ),
              );
            },
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
