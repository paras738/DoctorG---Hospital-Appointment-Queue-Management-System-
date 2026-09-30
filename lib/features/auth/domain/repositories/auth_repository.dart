import '../models/user_profile.dart';

/// Abstract Authentication Repository
/// Designed to support Email/Password + Google Sign-In with ZERO SMS cost,
/// while providing pluggable Phone OTP methods for future activation.
abstract class AuthRepository {
  /// Stream of user profile changes
  Stream<UserProfile?> get authStateChanges;

  /// Retrieves current logged-in user profile
  Future<UserProfile?> getCurrentUserProfile();

  /// Sign in with Email and Password
  Future<UserProfile> signInWithEmail({
    required String email,
    required String password,
  });

  /// Sign up with Email, Password, Full Name and initial Role
  Future<UserProfile> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  });

  /// Sign in using Google OAuth
  Future<UserProfile> signInWithGoogle();

  /// Pluggable Phone OTP: Send OTP SMS (zero-rewrite ready when funded)
  Future<void> sendPhoneOtp(String phoneNumber);

  /// Pluggable Phone OTP: Verify token and create/retrieve profile
  Future<UserProfile> verifyPhoneOtp({
    required String phoneNumber,
    required String token,
  });

  /// Update user role (e.g. on first Google login)
  Future<UserProfile> updateUserRole(String userId, UserRole role);

  /// Sign out
  Future<void> signOut();
}
