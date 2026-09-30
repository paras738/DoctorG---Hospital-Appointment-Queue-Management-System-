import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/supabase_auth_repository.dart';

final authProfileStreamProvider = StreamProvider<UserProfile?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<UserProfile?>>((ref) {
      final repo = ref.watch(authRepositoryProvider);
      return AuthController(repo);
    });

class AuthController extends StateNotifier<AsyncValue<UserProfile?>> {
  final AuthRepository _repo;

  AuthController(this._repo) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final profile = await _repo.getCurrentUserProfile();
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final profile = await _repo.signInWithEmail(
        email: email,
        password: password,
      );
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    state = const AsyncValue.loading();
    try {
      final profile = await _repo.signUpWithEmail(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
      );
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final profile = await _repo.signInWithGoogle();
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> sendPhoneOtp(String phoneNumber) async {
    await _repo.sendPhoneOtp(phoneNumber);
  }

  Future<void> verifyPhoneOtp({
    required String phoneNumber,
    required String token,
  }) async {
    state = const AsyncValue.loading();
    try {
      final profile = await _repo.verifyPhoneOtp(
        phoneNumber: phoneNumber,
        token: token,
      );
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> selectRole(UserRole role) async {
    final current = state.value;
    if (current == null) return;
    state = const AsyncValue.loading();
    try {
      final updated = await _repo.updateUserRole(current.id, role);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AsyncValue.data(null);
  }
}
