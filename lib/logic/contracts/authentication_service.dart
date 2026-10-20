class AuthenticatedUser {
  const AuthenticatedUser({
    required this.uid,
    required this.email,
    this.displayName,
  });

  final String uid;
  final String email;
  final String? displayName;
}

class AuthResult {
  const AuthResult({
    required this.isSuccess,
    this.message,
    this.user,
  });

  final bool isSuccess;
  final String? message;
  final AuthenticatedUser? user;

  factory AuthResult.success([
    AuthenticatedUser? user,
    String? message,
  ]) {
    return AuthResult(isSuccess: true, user: user, message: message);
  }

  factory AuthResult.failure(String message) {
    return AuthResult(isSuccess: false, message: message);
  }
}

abstract interface class AuthenticationService {
  bool get isInitialized;
  AuthenticatedUser? get currentUser;
  Stream<AuthenticatedUser?> get authStateChanges;

  Future<AuthResult> signIn({
    required String email,
    required String password,
  });

  Future<AuthResult> register({
    required String email,
    required String password,
    required String displayName,
  });

  Future<AuthResult> sendPasswordResetEmail({required String email});

  Future<AuthResult> updatePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<AuthResult> updateDisplayName(String displayName);

  Future<void> signOut();
}
