import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return SupabaseAuthRepository(supabase);
});

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _supabase;

  SupabaseAuthRepository(this._supabase);

  @override
  Stream<UserProfile?> get authStateChanges {
    return _supabase.auth.onAuthStateChange.asyncMap((event) async {
      final user = event.session?.user;
      if (user == null) return null;
      return await _fetchProfile(user.id);
    });
  }

  @override
  Future<UserProfile?> getCurrentUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    return await _fetchProfile(user.id);
  }

  @override
  Future<UserProfile> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Authentication failed: No user returned');
    }

    final profile = await _fetchProfile(user.id);
    if (profile == null) {
      throw Exception('User profile not found in database');
    }
    return profile;
  }

  @override
  Future<UserProfile> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim(), 'role': role.toDbValue()},
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Signup failed: No user created');
    }

    // Attempt to read profile created by handle_new_user trigger
    var profile = await _fetchProfile(user.id);
    if (profile == null) {
      // Fallback manual profile insertion if trigger had latency
      final row = {
        'id': user.id,
        'email': user.email,
        'full_name': fullName.trim(),
        'role': role.toDbValue(),
      };
      await _supabase.from('profiles').upsert(row);
      profile = UserProfile.fromJson(row);
    }
    return profile;
  }

  @override
  Future<UserProfile> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.doctorg.app://login-callback/',
    );
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Google Sign-In canceled or pending redirect');
    }
    final profile = await _fetchProfile(user.id);
    if (profile == null) {
      final newProfile = UserProfile(
        id: user.id,
        email: user.email ?? '',
        fullName: user.userMetadata?['full_name'] ?? 'DoctorG User',
        role: UserRole.patient,
        createdAt: DateTime.now(),
      );
      await _supabase.from('profiles').upsert(newProfile.toJson());
      return newProfile;
    }
    return profile;
  }

  @override
  Future<void> sendPhoneOtp(String phoneNumber) async {
    await _supabase.auth.signInWithOtp(phone: phoneNumber);
  }

  @override
  Future<UserProfile> verifyPhoneOtp({
    required String phoneNumber,
    required String token,
  }) async {
    final response = await _supabase.auth.verifyOTP(
      phone: phoneNumber,
      token: token,
      type: OtpType.sms,
    );

    final user = response.user;
    if (user == null) {
      throw Exception('OTP verification failed');
    }

    var profile = await _fetchProfile(user.id);
    if (profile == null) {
      final newProfile = UserProfile(
        id: user.id,
        email: '',
        phone: phoneNumber,
        fullName: 'Patient',
        role: UserRole.patient,
        createdAt: DateTime.now(),
      );
      await _supabase.from('profiles').upsert(newProfile.toJson());
      return newProfile;
    }
    return profile;
  }

  @override
  Future<UserProfile> updateUserRole(String userId, UserRole role) async {
    await _supabase
        .from('profiles')
        .update({'role': role.toDbValue()})
        .eq('id', userId);

    final profile = await _fetchProfile(userId);
    if (profile == null) {
      throw Exception('Failed to update role');
    }
    return profile;
  }

  @override
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Future<UserProfile?> _fetchProfile(String userId) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data == null) return null;
      return UserProfile.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}
