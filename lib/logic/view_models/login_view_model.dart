import 'package:smart_rice_warehouse/logic/providers/auth_provider.dart';

class LoginViewModel {
  const LoginViewModel(this.auth);
  final AuthProvider auth;

  Future<({bool success, String? message})> signIn({
    required String email,
    required String password,
    required bool remember,
  }) async {
    final cleanEmail = email.trim();
    if (auth.isCloudAuthEnabled) {
      final result = await auth.loginWithFirebase(
        email: cleanEmail,
        password: password,
        remember: remember,
      );
      if (result.success) return result;

      return (
        success: false,
        message: result.message ??
            auth.authError ??
            'Email hoặc mật khẩu không chính xác.',
      );
    }

    if (auth.login(
      email: cleanEmail,
      password: password,
      remember: remember,
    )) {
      return (success: true, message: null);
    }

    return (
      success: false,
      message: auth.authError ?? 'Email hoặc mật khẩu không chính xác.',
    );
  }
}
