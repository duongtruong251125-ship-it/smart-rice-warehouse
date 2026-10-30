import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_rice_warehouse/logic/contracts/authentication_service.dart';

/// Supabase implementation kept behind AuthenticationService so the UI and
/// providers do not depend on a backend SDK.
class SupabaseAuthService implements AuthenticationService {
  SupabaseAuthService({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  @override
  bool get isInitialized => true;

  @override
  AuthenticatedUser? get currentUser =>
      _toAuthenticatedUser(_client.auth.currentUser);

  @override
  Stream<AuthenticatedUser?> get authStateChanges =>
      _client.auth.onAuthStateChange
          .map((state) => _toAuthenticatedUser(state.session?.user));

  @override
  Future<AuthResult> signIn(
      {required String email, required String password}) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return AuthResult.success(
        _toAuthenticatedUser(response.user),
        'Đăng nhập thành công!',
      );
    } on AuthException catch (error) {
      return AuthResult.failure(_authMessage(error));
    } catch (error) {
      return AuthResult.failure('Lỗi đăng nhập: $error');
    }
  }

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'display_name': displayName.trim()},
      );
      return AuthResult.success(
        _toAuthenticatedUser(response.user),
        response.session == null
            ? 'Đã tạo tài khoản. Vui lòng xác minh email trước khi đăng nhập.'
            : 'Tạo tài khoản thành công!',
      );
    } on AuthException catch (error) {
      return AuthResult.failure(_authMessage(error));
    } catch (error) {
      return AuthResult.failure('Lỗi tạo tài khoản: $error');
    }
  }

  @override
  Future<AuthResult> sendPasswordResetEmail({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
      return AuthResult.success(
        null,
        'Đã gửi liên kết khôi phục mật khẩu. Vui lòng kiểm tra email.',
      );
    } on AuthException catch (error) {
      return AuthResult.failure(_authMessage(error));
    } catch (error) {
      return AuthResult.failure('Không thể gửi email khôi phục: $error');
    }
  }

  @override
  Future<AuthResult> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _client.auth.updateUser(
        UserAttributes(password: newPassword, currentPassword: currentPassword),
      );
      return AuthResult.success(_toAuthenticatedUser(response.user));
    } on AuthException catch (error) {
      return AuthResult.failure(_authMessage(error));
    } catch (error) {
      return AuthResult.failure('Không thể đổi mật khẩu: $error');
    }
  }

  @override
  Future<AuthResult> updateDisplayName(String displayName) async {
    try {
      final response = await _client.auth.updateUser(
        UserAttributes(data: {'display_name': displayName.trim()}),
      );
      return AuthResult.success(_toAuthenticatedUser(response.user));
    } on AuthException catch (error) {
      return AuthResult.failure(_authMessage(error));
    } catch (error) {
      return AuthResult.failure('Không thể cập nhật tên: $error');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (error) {
      debugPrint('Không thể đăng xuất Supabase: $error');
      rethrow;
    }
  }

  AuthenticatedUser? _toAuthenticatedUser(User? user) {
    if (user == null) return null;
    return AuthenticatedUser(
      uid: user.id,
      email: user.email ?? '',
      displayName: user.userMetadata?['display_name'] as String?,
    );
  }

  String _authMessage(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Email hoặc mật khẩu không chính xác.';
    }
    if (message.contains('already registered')) {
      return 'Email này đã được đăng ký tài khoản trước đó.';
    }
    if (message.contains('email not confirmed')) {
      return 'Vui lòng xác minh email trước khi đăng nhập.';
    }
    if (message.contains('password should be at least')) {
      return 'Mật khẩu quá yếu. Vui lòng nhập tối thiểu 6 ký tự.';
    }
    return error.message;
  }
}
