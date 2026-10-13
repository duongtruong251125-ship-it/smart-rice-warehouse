import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/firebase_options.dart';

/// Kết quả trả về từ các tác vụ Firebase Authentication
class FirebaseAuthResult {
  final bool isSuccess;
  final String? message;
  final User? user;

  const FirebaseAuthResult({
    required this.isSuccess,
    this.message,
    this.user,
  });

  factory FirebaseAuthResult.success([User? user, String? message]) {
    return FirebaseAuthResult(isSuccess: true, user: user, message: message);
  }

  factory FirebaseAuthResult.failure(String message) {
    return FirebaseAuthResult(isSuccess: false, message: message);
  }
}

/// Dịch vụ quản lý xác thực Firebase với cơ chế Safe Fallback
/// Tự động thích ứng nếu chưa cấu hình google-services.json hoặc đang chạy offline/test.
class FirebaseAuthService {
  FirebaseAuthService._();
  static final FirebaseAuthService instance = FirebaseAuthService._();

  bool _isInitialized = false;

  FirebaseAuth? get _auth {
    if (!_isInitialized) return null;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  /// Khởi tạo an toàn Firebase Core với DefaultFirebaseOptions
  Future<bool> initialize() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        _isInitialized = true;
        return true;
      }
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (_) {
        await Firebase.initializeApp();
      }
      _isInitialized = true;
      debugPrint('🔥 Firebase Core & Auth đã sẵn sàng hoạt động.');
      return true;
    } catch (e) {
      _isInitialized = false;
      debugPrint('⚡ Firebase chạy chế độ Local Fallback: $e');
      return false;
    }
  }

  /// Đăng nhập bằng Email & Mật khẩu qua Firebase
  Future<FirebaseAuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final auth = _auth;
    if (auth == null) {
      return FirebaseAuthResult.failure(
        'Dịch vụ tài khoản chưa sẵn sàng. Vui lòng thử lại sau.',
      );
    }

    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return FirebaseAuthResult.success(
          credential.user, 'Đăng nhập thành công!');
    } on FirebaseAuthException catch (e) {
      return FirebaseAuthResult.failure(_mapErrorCode(e.code, e.message));
    } catch (e) {
      return FirebaseAuthResult.failure('Lỗi đăng nhập: $e');
    }
  }

  /// Đăng ký tài khoản thủ kho mới trên Firebase Authentication
  Future<FirebaseAuthResult> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final auth = _auth;
    if (auth == null) {
      return FirebaseAuthResult.failure(
        'Dịch vụ tài khoản chưa sẵn sàng. Vui lòng thử lại sau.',
      );
    }

    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Tài khoản đã được tạo thành công. Cập nhật tên là bước bổ sung,
      // không được biến một lỗi hồ sơ thành thông báo tạo tài khoản thất bại.
      if (displayName.trim().isNotEmpty && credential.user != null) {
        try {
          await credential.user!.updateDisplayName(displayName.trim());
          await credential.user!.reload();
        } catch (error) {
          debugPrint('Không thể cập nhật tên hiển thị: $error');
        }
      }

      return FirebaseAuthResult.success(
        auth.currentUser ?? credential.user,
        'Tạo tài khoản thành công!',
      );
    } on FirebaseAuthException catch (e) {
      return FirebaseAuthResult.failure(_mapErrorCode(e.code, e.message));
    } catch (e) {
      return FirebaseAuthResult.failure('Lỗi tạo tài khoản: $e');
    }
  }

  /// Gửi email khôi phục mật khẩu qua Firebase
  Future<FirebaseAuthResult> sendPasswordResetEmail(
      {required String email}) async {
    final auth = _auth;
    if (auth == null) {
      return FirebaseAuthResult.failure(
        'Dịch vụ tài khoản chưa sẵn sàng. Vui lòng thử lại sau.',
      );
    }

    try {
      await auth.sendPasswordResetEmail(email: email.trim());
      return FirebaseAuthResult.success(
        null,
        'Đã gửi liên kết khôi phục mật khẩu vào hòm thư $email. Vui lòng kiểm tra hộp thư đến.',
      );
    } on FirebaseAuthException catch (e) {
      return FirebaseAuthResult.failure(_mapErrorCode(e.code, e.message));
    } catch (e) {
      return FirebaseAuthResult.failure('Lỗi gửi email đặt lại: $e');
    }
  }

  /// Đăng xuất khỏi Firebase
  Future<void> signOut() async {
    try {
      await _auth?.signOut();
    } catch (e) {
      debugPrint('Lỗi đăng xuất Firebase: $e');
    }
  }

  /// Chuyển đổi mã lỗi Firebase sang tiếng Việt dễ hiểu
  String _mapErrorCode(String code, String? defaultMessage) {
    switch (code) {
      case 'user-not-found':
        return 'Không tìm thấy tài khoản với email này.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Mật khẩu hoặc thông tin đăng nhập không chính xác.';
      case 'email-already-in-use':
        return 'Email này đã được đăng ký tài khoản trước đó.';
      case 'invalid-email':
        return 'Địa chỉ email không hợp lệ.';
      case 'weak-password':
        return 'Mật khẩu quá yếu. Vui lòng nhập tối thiểu 6 ký tự.';
      case 'network-request-failed':
        return 'Không thể kết nối máy chủ. Vui lòng kiểm tra Internet.';
      case 'operation-not-allowed':
        return 'Phương thức đăng nhập bằng email chưa được bật cho dự án.';
      case 'invalid-api-key':
      case 'app-not-authorized':
        return 'Cấu hình dịch vụ tài khoản chưa hợp lệ.';
      case 'too-many-requests':
        return 'Bạn đã thử quá nhiều lần. Vui lòng chờ ít phút và thử lại.';
      case 'user-disabled':
        return 'Tài khoản này đã bị tạm khóa.';
      default:
        return defaultMessage ?? 'Đã xảy ra lỗi xác thực ($code).';
    }
  }
}
