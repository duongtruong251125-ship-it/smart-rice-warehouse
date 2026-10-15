import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/core/services/firebase_auth_service.dart';
import 'package:smart_rice_warehouse/data/mock_data.dart';
import 'package:smart_rice_warehouse/models/user_model.dart';
import 'package:smart_rice_warehouse/repositories/contracts/repository_exception.dart';
import 'package:smart_rice_warehouse/repositories/contracts/user_profile_repository.dart';

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
    AuthenticationService? authenticationService,
    this.userProfileRepository,
    this.loadAvatarPath,
    this.onAvatarPersist,
  })  : _email = (email ?? 'admin@gmail.com').trim().toLowerCase(),
        _passwordHash = passwordHash ?? _hash('123456'),
        _userName = userName ?? MockData.adminUser.name,
        _userRole = userRole ?? MockData.adminUser.role,
        _avatarPath = avatarPath,
        _rememberedSession = rememberedSession,
        _authenticationService =
            authenticationService ?? FirebaseAuthService.instance {
    if (isCloudAuthEnabled) {
      _bindFirebaseSession();
    } else {
      if (rememberedSession) _currentUser = _buildLegacyUser();
      _markAuthReady();
    }
  }

  final String _email;
  String _passwordHash;
  bool _rememberedSession;
  String _userName;
  String _userRole;
  String? _avatarPath;

  final void Function(String email, String passwordHash, bool remembered)?
      onPersist;
  final void Function(String name, String role, String? avatarPath)?
      onProfilePersist;
  final AuthenticationService _authenticationService;
  final UserProfileRepository? userProfileRepository;
  final Future<String?> Function(String uid)? loadAvatarPath;
  final void Function(String uid, String? avatarPath)? onAvatarPersist;

  final Completer<void> _authReadyCompleter = Completer<void>();
  StreamSubscription<AuthenticatedUser?>? _authSubscription;
  UserModel? _currentUser;
  bool _isAuthReady = false;
  bool _authOperationInProgress = false;
  int _sessionRevision = 0;
  String? _authError;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAuthReady => _isAuthReady;
  bool get isCloudAuthEnabled => userProfileRepository != null;
  String? get authError => _authError;

  Future<void> waitUntilReady({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (_isAuthReady) return;
    await _authReadyCompleter.future.timeout(timeout, onTimeout: () {});
  }

  void _bindFirebaseSession() {
    _authSubscription = _authenticationService.authStateChanges.listen(
      (user) {
        if (_authOperationInProgress) return;
        unawaited(_applyFirebaseSession(user));
      },
      onError: (Object error) {
        _authError = 'Không thể khôi phục phiên đăng nhập: $error';
        _currentUser = null;
        _markAuthReady();
        notifyListeners();
      },
    );
  }

  Future<void> _applyFirebaseSession(AuthenticatedUser? user) async {
    final revision = ++_sessionRevision;
    if (user == null) {
      _currentUser = null;
      _authError = null;
      _markAuthReady();
      notifyListeners();
      return;
    }

    final resolution = await _resolveCloudProfile(
      user,
      createPendingIfMissing: true,
    );
    if (revision != _sessionRevision) return;

    if (!resolution.success) {
      _currentUser = null;
      _authError = resolution.message;
      await _authenticationService.signOut();
    } else {
      _authError = null;
    }
    _markAuthReady();
    notifyListeners();
  }

  void _markAuthReady() {
    _isAuthReady = true;
    if (!_authReadyCompleter.isCompleted) _authReadyCompleter.complete();
  }

  /// Legacy local/demo login retained temporarily for tests and screens that
  /// have not been migrated. Production UI no longer falls back to this path.
  bool login({
    required String email,
    required String password,
    bool remember = false,
  }) {
    if (isCloudAuthEnabled) return false;
    final isValid = email.trim().toLowerCase() == _email &&
        _hash(password) == _passwordHash;

    if (!isValid) return false;

    _currentUser = _buildLegacyUser();
    _rememberedSession = remember;
    _persistLegacyAuth();
    notifyListeners();
    return true;
  }

  Future<({bool success, String? message})> loginWithFirebase({
    required String email,
    required String password,
    bool remember = false,
  }) async {
    if (!isCloudAuthEnabled) {
      return (success: false, message: 'Dịch vụ hồ sơ chưa sẵn sàng.');
    }

    _authOperationInProgress = true;
    try {
      final result = await _authenticationService.signIn(
        email: email,
        password: password,
      );
      final user = result.user;
      if (!result.isSuccess || user == null) {
        return (success: false, message: result.message);
      }

      final resolution = await _resolveCloudProfile(
        user,
        createPendingIfMissing: true,
      );
      if (!resolution.success) {
        await _authenticationService.signOut();
        _currentUser = null;
        _authError = resolution.message;
        notifyListeners();
        return (success: false, message: resolution.message);
      }

      _rememberedSession = remember;
      _authError = null;
      _markAuthReady();
      notifyListeners();
      return (success: true, message: result.message);
    } finally {
      _authOperationInProgress = false;
    }
  }

  Future<({bool success, String? message})> registerWithFirebase({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    if (!isCloudAuthEnabled) {
      return (success: false, message: 'Dịch vụ hồ sơ chưa sẵn sàng.');
    }
    // The requested role is deliberately ignored. Security Rules and an admin
    // account are the only authorities allowed to grant roles.

    _authOperationInProgress = true;
    try {
      final result = await _authenticationService.register(
        email: email,
        password: password,
        displayName: name,
      );
      final user = result.user;
      if (!result.isSuccess || user == null) {
        return (success: false, message: result.message);
      }

      try {
        await userProfileRepository!.createPendingProfile(
          uid: user.uid,
          email: user.email.isEmpty ? email : user.email,
          displayName: name,
        );
      } catch (error) {
        await _authenticationService.signOut();
        return (
          success: false,
          message: 'Đã tạo tài khoản xác thực nhưng chưa thể tạo hồ sơ: $error',
        );
      }

      await _authenticationService.signOut();
      _currentUser = null;
      _authError = null;
      notifyListeners();
      return (
        success: true,
        message: 'Tài khoản đã được tạo và đang chờ quản trị viên kích hoạt.',
      );
    } finally {
      _authOperationInProgress = false;
    }
  }

  Future<({bool success, String? message})> _resolveCloudProfile(
    AuthenticatedUser user, {
    required bool createPendingIfMissing,
  }) async {
    try {
      var profile = await userProfileRepository!.getById(user.uid);
      if (profile == null && createPendingIfMissing) {
        await userProfileRepository!.createPendingProfile(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : user.email.split('@').first,
        );
        profile = await userProfileRepository!.getById(user.uid);
      }

      if (profile == null) {
        return (success: false, message: 'Không tìm thấy hồ sơ tài khoản.');
      }
      if (!profile.isActive) {
        return (
          success: false,
          message: 'Tài khoản đang chờ quản trị viên kích hoạt.',
        );
      }

      final localAvatar = await loadAvatarPath?.call(user.uid);
      _currentUser = profile.copyWith(
        email: user.email.isEmpty ? profile.email : user.email,
        avatarPath: localAvatar,
      );
      return (success: true, message: null);
    } catch (error) {
      return (success: false, message: 'Không thể tải hồ sơ tài khoản: $error');
    }
  }

  Future<({bool success, String? message})> resetPasswordWithFirebase(
    String email,
  ) async {
    final result = await _authenticationService.sendPasswordResetEmail(
      email: email,
    );
    return (success: result.isSuccess, message: result.message);
  }

  Future<({bool success, String? message})> changePasswordWithFirebase({
    required String current,
    required String replacement,
  }) async {
    if (!isCloudAuthEnabled) {
      final changed = changePassword(
        current: current,
        replacement: replacement,
      );
      return (
        success: changed,
        message: changed ? null : 'Mật khẩu hiện tại không chính xác.',
      );
    }
    final result = await _authenticationService.updatePassword(
      currentPassword: current,
      newPassword: replacement,
    );
    return (success: result.isSuccess, message: result.message);
  }

  Future<({bool success, String? message})> updateProfileWithFirebase({
    required String name,
    String? avatarPath,
  }) async {
    final normalizedName = name.trim();
    final user = _currentUser;
    if (user == null || normalizedName.isEmpty) {
      return (success: false, message: 'Họ tên không được để trống.');
    }

    if (!isCloudAuthEnabled) {
      final updated = updateProfile(
        name: normalizedName,
        role: user.role,
        avatarPath: avatarPath,
      );
      return (
        success: updated,
        message: updated ? null : 'Không thể cập nhật.'
      );
    }

    try {
      await userProfileRepository!.updateDisplayName(
        uid: user.id,
        displayName: normalizedName,
      );
      final authResult =
          await _authenticationService.updateDisplayName(normalizedName);
      if (!authResult.isSuccess) {
        return (success: false, message: authResult.message);
      }
      onAvatarPersist?.call(user.id, avatarPath);
      _currentUser = user.copyWith(
        name: normalizedName,
        avatarPath: avatarPath,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      return (success: true, message: null);
    } on RepositoryException catch (error) {
      return (success: false, message: error.message);
    } catch (error) {
      return (success: false, message: 'Không thể cập nhật hồ sơ: $error');
    }
  }

  Future<void> logoutWithFirebase() async {
    if (!isCloudAuthEnabled) {
      logout();
      return;
    }
    ++_sessionRevision;
    await _authenticationService.signOut();
    _currentUser = null;
    _rememberedSession = false;
    _authError = null;
    notifyListeners();
  }

  void logout() {
    if (isCloudAuthEnabled) {
      unawaited(logoutWithFirebase());
      return;
    }
    if (_currentUser == null) return;
    _currentUser = null;
    _rememberedSession = false;
    _persistLegacyAuth();
    notifyListeners();
  }

  /// Legacy-only password update kept until the local authentication data is
  /// removed by the migration task.
  bool changePassword({
    required String current,
    required String replacement,
  }) {
    if (isCloudAuthEnabled ||
        _hash(current) != _passwordHash ||
        replacement.length < 6) {
      return false;
    }
    _passwordHash = _hash(replacement);
    _persistLegacyAuth();
    return true;
  }

  /// Legacy-only profile update. Cloud users use updateProfileWithFirebase so
  /// their role cannot be changed by the client.
  bool updateProfile({
    required String name,
    required String role,
    String? avatarPath,
  }) {
    if (isCloudAuthEnabled) return false;
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
    _currentUser = _buildLegacyUser();
    onProfilePersist?.call(_userName, _userRole, _avatarPath);
    notifyListeners();
    return true;
  }

  void _persistLegacyAuth() =>
      onPersist?.call(_email, _passwordHash, _rememberedSession);

  UserModel _buildLegacyUser() => UserModel(
        id: MockData.adminUser.id,
        name: _userName,
        email: _email,
        role: _userRole,
        avatarPath: _avatarPath,
      );

  static String _hash(String password) =>
      sha256.convert(utf8.encode('smart-rice-warehouse::$password')).toString();

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
