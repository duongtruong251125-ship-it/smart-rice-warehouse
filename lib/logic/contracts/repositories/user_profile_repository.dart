import 'package:smart_rice_warehouse/logic/models/user_model.dart';

abstract interface class UserProfileRepository {
  Stream<List<UserModel>> watchAll();

  Stream<UserModel?> watchById(String uid);

  Future<UserModel?> getById(String uid);

  /// Creates a profile that cannot access business data until an administrator
  /// activates it. The client never chooses its own role or active state.
  Future<void> createPendingProfile({
    required String uid,
    required String email,
    required String displayName,
  });

  Future<void> updateDisplayName({
    required String uid,
    required String displayName,
  });

  /// Administrative operation. Supabase row-level security policies are the final
  /// authority and reject this call for non-admin accounts.
  Future<void> updateAccess({
    required String uid,
    required String role,
    required bool isActive,
  });

  /// Confirms an account email through a server-side admin operation.
  /// Returns true when the email had already been confirmed.
  Future<bool> confirmEmail(String uid);
}
