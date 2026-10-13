import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/core/services/firebase_auth_service.dart';
import 'package:smart_rice_warehouse/data/mock_data.dart';
import 'package:smart_rice_warehouse/models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    String? email,
    String? passwordHash,
    String? userName,
    String? userRole,
    String? avatarPath,
    bool rememberedSession = false,
    this.onPersist,
    this.onProfilePersist,
  })  : _email = (email ?? 'admin@gmail.com').trim().toLowerCase(),
        _passwordHash = passwordHash ?? _hash('123456'),
        _userName = userName ?? MockData.adminUser.name,
        _userRole = userRole ?? MockData.adminUser.role,
        _avatarPath = avatarPath,
        _rememberedSession = rememberedSession {
    if (rememberedSession) _currentUser = _buildUser();
  }

  String _email;
  String _passwordHash;
  bool _rememberedSession;
  String _userName;
  String _userRole;
  String? _avatarPath;
  final void Function(String email, String passwordHash, bool remembered)?
      onPersist;
  final void Function(String name, String role, String? avatarPath)?
      onProfilePersist;

  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  /// Đăng nhập Cục bộ (Local / Demo)
  bool login({
    required String email,
    required String password,
    bool remember = false,
  }) {
    final isValid = email.trim().toLowerCase() == _email &&
        _hash(password) == _passwordHash;

    if (!isValid) {
      return false;
    }

    _currentUser = _buildUser();
    _rememberedSession = remember;
    _persist();
    notifyListeners();
    return true;
  }

  /// Đăng nhập qua Firebase Authentication (Cloud)
  Future<({bool success, String? message})> loginWithFirebase({
    required String email,
    required String password,
    bool remember = false,
  }) async {
    final result = await FirebaseAuthService.instance.signIn(
      email: email,
      password: password,
    );

    if (result.isSuccess && result.user != null) {
      final user = result.user!;
      _email = (user.email ?? email).trim().toLowerCase();
      _passwordHash = _hash(password);
      if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
        _userName = user.displayName!.trim();
      }
      _rememberedSession = remember;
      _currentUser = _buildUser();
      _persist();
      notifyListeners();
      return (success: true, message: result.message);
    }

    return (success: false, message: result.message);
  }

  /// Đăng ký tài khoản thủ kho mới trên Firebase Authentication
  Future<({bool success, String? message})> registerWithFirebase({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    final result = await FirebaseAuthService.instance.register(
      email: email,
      password: password,
      displayName: name,
    );

    if (result.isSuccess && result.user != null) {
      _email = email.trim().toLowerCase();
      _passwordHash = _hash(password);
      _userName = name.trim();
      _userRole = role.trim();
      _currentUser = _buildUser();
      _persist();
      notifyListeners();
      return (success: true, message: result.message);
    }

    return (success: false, message: result.message);
  }

  /// Khôi phục mật khẩu qua Firebase Email
  Future<({bool success, String? message})> resetPasswordWithFirebase(
    String email,
  ) async {
    final result = await FirebaseAuthService.instance.sendPasswordResetEmail(
      email: email,
    );
    return (success: result.isSuccess, message: result.message);
  }

  void logout() {
    if (_currentUser == null) {
      return;
    }

    // Đăng xuất cả Firebase (nếu có kết nối)
    FirebaseAuthService.instance.signOut();

    _currentUser = null;
    _rememberedSession = false;
    _persist();
    notifyListeners();
  }

  bool changePassword({required String current, required String replacement}) {
    if (_hash(current) != _passwordHash || replacement.length < 6) return false;
    _passwordHash = _hash(replacement);
    _persist();
    return true;
  }

  bool updateProfile({
    required String name,
    required String role,
    String? avatarPath,
  }) {
    final normalizedName = name.trim();
    final normalizedRole = role.trim();
    if (_currentUser == null ||
        normalizedName.isEmpty ||
        normalizedRole.isEmpty) {
      return false;
    }
    _userName = normalizedName;
    _userRole = normalizedRole;
    _avatarPath = avatarPath ?? _avatarPath;
    _currentUser = _buildUser();
    onProfilePersist?.call(_userName, _userRole, _avatarPath);
    notifyListeners();
    return true;
  }

  void _persist() => onPersist?.call(_email, _passwordHash, _rememberedSession);

  UserModel _buildUser() => UserModel(
        id: MockData.adminUser.id,
        name: _userName,
        email: _email,
        role: _userRole,
        avatarPath: _avatarPath,
      );

  static String _hash(String password) =>
      sha256.convert(utf8.encode('smart-rice-warehouse::$password')).toString();
}
