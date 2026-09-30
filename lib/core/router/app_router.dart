import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/role_selection_screen.dart';
import '../../features/auth/domain/models/user_profile.dart';

import '../../features/doctor_directory/presentation/screens/doctor_directory_screen.dart';
import '../../features/doctor_directory/presentation/screens/doctor_profile_screen.dart';
import '../../features/home/presentation/screens/patient_home_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProfileStreamProvider);

  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      final user = authState.valueOrNull;

      if (isLoading) return null; // Wait for session load

      final isLoggingIn =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      // Unauthenticated users can only view login or register
      if (user == null && !isLoggingIn) {
        return '/login';
      }

      // If user is authenticated and is on login/register page, route by role
      if (user != null && isLoggingIn) {
        if (user.role == UserRole.doctor) {
          return '/doctor-dashboard';
        }
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/role-selection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const PatientHomeScreen(),
      ),
      GoRoute(
        path: '/doctor/:id',
        builder: (context, state) {
          final docId = state.pathParameters['id'] ?? '';
          return DoctorProfileScreen(doctorId: docId);
        },
      ),
      GoRoute(
        path: '/doctor-dashboard',
        builder: (context, state) => const DoctorDashboardPlaceholder(),
      ),
    ],
  );
});

/// Temporary placeholder for Patient Home (Phase 2 & 3 will build full screens)
class PatientHomePlaceholder extends ConsumerWidget {
  const PatientHomePlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DoctorG — Patient Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.health_and_safety_rounded,
                size: 72,
                color: Color(0xFF00897B),
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome, ${user?.fullName.isNotEmpty == true ? user!.fullName : "Patient"}!',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Phase 1 Base Architecture, Supabase Migrations & Auth Complete.\nReady for Phase 2: Doctor Directory, Search & Bayesian Ranking.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Temporary placeholder for Doctor Dashboard (Phase 5 will build full screens)
class DoctorDashboardPlaceholder extends ConsumerWidget {
  const DoctorDashboardPlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DoctorG — Clinic Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.medical_services_rounded,
                size: 72,
                color: Color(0xFF0277BD),
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome, ${user?.fullName.isNotEmpty == true ? user!.fullName : "Doctor"}!',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Doctor OPD Queue & Schedule Management ready for Phase 5.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
