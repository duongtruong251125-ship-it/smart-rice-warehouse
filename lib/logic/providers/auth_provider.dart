import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/logic/contracts/authentication_service.dart';
import 'package:smart_rice_warehouse/logic/services/auth_profile_diagnostics.dart';
import 'package:smart_rice_warehouse/logic/models/user_model.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/repository_exception.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/user_profile_repository.dart';

class AuthProvider extends ChangeNotifier {
  static const List<UserModel> defaultAccounts = <UserModel>[
    UserModel(
      id: 'user-admin',
      name: 'Admin',
      email: 'admin@gmail.com',
      role: 'admin',
      isActive: true,
    ),
    UserModel(
      id: 'user-staff-01',
      name: 'Nguyễn Văn Hùng',
      email: 'staff@gmail.com',
      role: 'staff',
      isActive: true,
    ),
    UserModel(
      id: 'user-staff-02',
      name: 'Trần Thị Mai',
      email: 'kiemke@gmail.com',
      role: 'staff',
      isActive: true,
    ),
    UserModel(
      id: 'user-staff-03',
      name: 'Lê Hoàng Nam',
      email: 'nhanvienmoi@gmail.com',
      role: 'staff',
      isActive: false,
    ),
  ];

  AuthProvider({
    this.demoMode = false,
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
    this.onForceCloudSync,
    this.onLegacyMigration,
  })  : _email = (email ?? 'admin@gmail.com').trim().toLowerCase(),
        _passwordHash = passwordHash ?? _hash('123456'),
        _userName = userName ?? 'Admin',
        _userRole = userRole ?? 'admin',
        _avatarPath = avatarPath,
        _rememberedSession = rememberedSession,
        _authenticationService =
            authenticationService ?? const _NoOpAuthenticationService(),
        _managedUsers = demoMode && userProfileRepository == null
            ? List<UserModel>.from(defaultAccounts)
            : [] {
    if (isCloudAuthEnabled) {
      _bindFirebaseSession();
      if (userProfileRepository == null ||
          !_authenticationService.isInitialized) {
        _authError = 'Dịch vụ xác thực cloud chưa sẵn sàng.';
        _markAuthReady();
      }
    } else {
      final account = _demoAccount(_email);
      if (rememberedSession && account?.isActive == true) {
        _currentUser = _buildLegacyUser();
      }
      _markAuthReady();
    }
  }

  String _email;
  final bool demoMode;
  String _passwordHash;
  bool _rememberedSession;
  String _userName;
  String _userRole;
  String? _avatarPath;
  final List<UserModel> _managedUsers;

  final void Function(String email, String passwordHash, bool remembered)?
      onPersist;
  final void Function(String name, String role, String? avatarPath)?
      onProfilePersist;
  final AuthenticationService _authenticationService;
  final UserProfileRepository? userProfileRepository;
  final Future<String?> Function(String uid)? loadAvatarPath;
  final void Function(String uid, String? avatarPath)? onAvatarPersist;
  final Future<({bool success, String? message})> Function()? onForceCloudSync;
  final Future<({bool success, String? message})> Function()? onLegacyMigration;
  bool _isMigratingLegacy = false;
  bool get isMigratingLegacy => _isMigratingLegacy;
  bool get canMigrateLegacy =>
      isAdmin && !isDemoMode && onLegacyMigration != null;

  Future<({bool success, String? message})> migrateLegacyData() async {
    if (!canMigrateLegacy || _isMigratingLegacy) {
      return (
        success: false,
        message: 'Không có quyền hoặc migration đang chạy.'
      );
    }
    _isMigratingLegacy = true;
    notifyListeners();
    try {
      return await onLegacyMigration!();
    } catch (error) {
      return (success: false, message: 'Không thể chuyển dữ liệu cũ: $error');
    } finally {
      _isMigratingLegacy = false;
      notifyListeners();
    }
  }

  final Completer<void> _authReadyCompleter = Completer<void>();
  StreamSubscription<AuthenticatedUser?>? _authSubscription;
  StreamSubscription<List<UserModel>>? _usersSubscription;
  StreamSubscription<UserModel?>? _profileSubscription;
  bool _disposed = false;
  bool _isRevoking = false;
  UserModel? _currentUser;
  bool _isAuthReady = false;
  bool _authOperationInProgress = false;
  int _sessionRevision = 0;
  String? _authError;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser?.isActive == true;
  bool get isAuthReady => _isAuthReady;
  bool get isDemoMode => demoMode && userProfileRepository == null;
  bool get isCloudAuthEnabled => !isDemoMode;
  String? get authError => _authError;
  bool get isAdmin => isLoggedIn && _currentUser?.role == 'admin';
  bool get isStaff => isLoggedIn && _currentUser?.role == 'staff';
  List<UserModel> get managedUsers =>
      List<UserModel>.unmodifiable(_managedUsers);

  void _bindManagedUsers() {
    _usersSubscription?.cancel();
    if (!isAdmin || userProfileRepository == null) return;
    final revision = _sessionRevision;
    _usersSubscription = userProfileRepository?.watchAll().listen(
      (remoteUsers) {
        if (_disposed || revision != _sessionRevision || !isAdmin) return;
        _managedUsers
          ..clear()
          ..addAll(remoteUsers);
        notifyListeners();
      },
      onError: (Object error) {
        if (_disposed || revision != _sessionRevision) return;
        _managedUsers.clear();
        _authError =
            'Không thể tải danh sách nhân sự. ${AuthProfileDiagnostics.readError(error)}';
        notifyListeners();
      },
    );
  }

  Future<({bool success, String? message})> updateUserAccess({
    required String uid,
    required String role,
    required bool isActive,
  }) async {
    if (!isAdmin) {
      return (
        success: false,
        message: 'Chỉ Quản trị viên mới có quyền phân quyền nhân sự.',
      );
    }
    if (uid.trim().isEmpty || !['admin', 'staff'].contains(role)) {
      return (success: false, message: 'Tài khoản hoặc chức vụ không hợp lệ.');
    }
    if (isCloudAuthEnabled) {
      if (userProfileRepository == null) {
        return (success: false, message: 'Dịch vụ hồ sơ chưa sẵn sàng.');
      }
      try {
        await userProfileRepository!.updateAccess(
          uid: uid,
          role: role,
          isActive: isActive,
        );
        // Only confirmed profile streams update roles and activation in cloud.
        return (
          success: true,
          message: 'Đã cập nhật quyền và trạng thái tài khoản.'
        );
      } catch (error) {
        return (
          success: false,
          message: error is RepositoryException
              ? error.message
              : 'Không thể cập nhật quyền trên máy chủ: $error'
        );
      }
    }
    if (_disposed) return (success: true, message: null);
    final index = _managedUsers.indexWhere((u) => u.id == uid);
    if (index != -1) {
      _managedUsers[index] = _managedUsers[index]
          .copyWith(role: role, isActive: isActive, updatedAt: DateTime.now());
    }
    if (_currentUser?.id == uid) {
      _currentUser = _currentUser!.copyWith(role: role, isActive: isActive);
      _userRole = role;
      if (!isActive) {
        await logoutWithFirebase();
      }
    }
    notifyListeners();
    return (
      success: true,
      message: 'Đã cập nhật quyền và trạng thái tài khoản.',
    );
  }

  bool _isRefreshingCloud = false;
  bool get isRefreshingCloud => _isRefreshingCloud;

  Future<({bool success, String? message})> triggerCloudSync() async {
    if (_disposed || _isRefreshingCloud) {
      return (success: false, message: 'Đang tải dữ liệu hoặc phiên đã đóng.');
    }
    if (isCloudAuthEnabled && !isLoggedIn) {
      return (success: false, message: 'Vui lòng đăng nhập để tải cloud.');
    }
    final revision = _sessionRevision;
    _isRefreshingCloud = true;
    notifyListeners();
    try {
      if (onForceCloudSync == null) {
        if (isCloudAuthEnabled) {
          return (
            success: false,
            message: 'Chức năng tải cloud chưa sẵn sàng.'
          );
        }
        return (
          success: true,
          message: 'Đã đồng bộ dữ liệu nội bộ SQLite và bộ nhớ đệm.',
        );
      }
      final result = await onForceCloudSync!();
      if (_disposed || revision != _sessionRevision) {
        return (success: false, message: 'Phiên đăng nhập đã thay đổi.');
      }
      return result;
    } catch (error) {
      return (success: false, message: 'Không thể đồng bộ dữ liệu: $error');
    } finally {
      _isRefreshingCloud = false;
      notifyListeners();
    }
  }

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
        unawaited(_revokeSession(AuthProfileDiagnostics.readError(error)));
      },
    );
  }

  Future<void> _applyFirebaseSession(AuthenticatedUser? user) async {
    if (_disposed) return;
    final revision = ++_sessionRevision;
    await _cancelProfileListeners();
    if (_disposed || revision != _sessionRevision) return;
    _currentUser = null;
    _managedUsers.clear();
    notifyListeners();
    if (user == null) {
      _currentUser = null;
      _markAuthReady();
      notifyListeners();
      return;
    }

    final resolution = await _resolveCloudProfile(
      user,
    );
    if (_disposed || revision != _sessionRevision) return;

    if (!resolution.success) {
      await _revokeSession(resolution.message ?? 'Không thể xác minh hồ sơ.');
      return;
    } else {
      _currentUser = resolution.profile;
      _authError = null;
      _watchCloudProfile(user.uid, revision);
      _bindManagedUsers();
    }
    _markAuthReady();
    notifyListeners();
  }

  void _markAuthReady() {
    _isAuthReady = true;
    if (!_authReadyCompleter.isCompleted) _authReadyCompleter.complete();
  }

  /// Sample credentials are available only in explicitly selected demo mode.
  bool login({
    required String email,
    required String password,
    bool remember = false,
  }) {
    if (!isDemoMode || _disposed) return false;
    final normalizedEmail = email.trim().toLowerCase();
    final selectedAccount = _demoAccount(normalizedEmail);
    if (selectedAccount == null || !selectedAccount.isActive) {
      _authError = 'Tài khoản không tồn tại hoặc chưa được kích hoạt.';
      return false;
    }
    final inputHash = _hash(password);

    if (normalizedEmail == _email && inputHash == _passwordHash) {
      _authError = null;
      _currentUser = _buildLegacyUser();
      _rememberedSession = remember;
      _persistLegacyAuth();
      notifyListeners();
      return true;
    }

    for (final account in _managedUsers) {
      if (account.email.trim().toLowerCase() == normalizedEmail &&
          (inputHash == _hash('123456') || inputHash == _passwordHash)) {
        if (!account.isActive) {
          _authError = 'Tài khoản đang chờ quản trị viên kích hoạt.';
          return false;
        }
        _authError = null;
        _email = normalizedEmail;
        _userName = account.name;
        _userRole = account.role;
        _currentUser = account.copyWith(avatarPath: _avatarPath);
        _rememberedSession = remember;
        _persistLegacyAuth();
        notifyListeners();
        return true;
      }
    }

    return false;
  }

  Future<({bool success, String? message})> loginWithFirebase({
    required String email,
    required String password,
    bool remember = false,
  }) async {
    if (!isCloudAuthEnabled ||
        userProfileRepository == null ||
        !_authenticationService.isInitialized) {
      return (success: false, message: 'Dịch vụ hồ sơ chưa sẵn sàng.');
    }
    if (_authOperationInProgress || _isRevoking || _disposed) {
      return (success: false, message: 'Đang xử lý xác thực.');
    }
    _authOperationInProgress = true;
    final revision = ++_sessionRevision;
    await _cancelProfileListeners();
    _currentUser = null;
    _managedUsers.clear();
    try {
      final result = await _authenticationService.signIn(
        email: email,
        password: password,
      );
      final user = result.user;
      if (_disposed || revision != _sessionRevision) {
        return (success: false, message: 'Phiên xác thực đã thay đổi.');
      }
      if (!result.isSuccess || user == null) {
        await _revokeSession(result.message ?? 'Đăng nhập thất bại.');
        return (success: false, message: result.message);
      }

      final resolution = await _resolveCloudProfile(
        user,
      );
      if (_disposed || revision != _sessionRevision) {
        return (success: false, message: 'Phiên xác thực đã thay đổi.');
      }
      if (!resolution.success) {
        await _revokeSession(resolution.message ?? 'Không thể xác minh hồ sơ.');
        return (success: false, message: resolution.message);
      }

      _currentUser = resolution.profile;
      _watchCloudProfile(user.uid, revision);
      _bindManagedUsers();
      _rememberedSession = remember;
      _authError = null;
      _markAuthReady();
      notifyListeners();
      return (success: true, message: result.message);
    } catch (error) {
      await _revokeSession(AuthProfileDiagnostics.readError(error));
      return (success: false, message: _authError);
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
    if (!isCloudAuthEnabled ||
        userProfileRepository == null ||
        !_authenticationService.isInitialized) {
      return (success: false, message: 'Dịch vụ hồ sơ chưa sẵn sàng.');
    }
    // The requested role is deliberately ignored. Security Rules and an admin
    // account are the only authorities allowed to grant roles.
    if (_authOperationInProgress || _isRevoking || _disposed) {
      return (success: false, message: 'Đang xử lý xác thực.');
    }
    _authOperationInProgress = true;
    ++_sessionRevision;
    await _cancelProfileListeners();
    _currentUser = null;
    _managedUsers.clear();
    notifyListeners();
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

      final effectiveEmail =
          (user.email.isEmpty ? email : user.email).trim().toLowerCase();
      try {
        await userProfileRepository!.createPendingProfile(
          uid: user.uid,
          email: effectiveEmail,
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
    } catch (error) {
      await _revokeSession('Không thể tạo tài khoản cloud: $error');
      return (success: false, message: _authError);
    } finally {
      _authOperationInProgress = false;
    }
  }

  Future<({bool success, String? message, UserModel? profile})>
      _resolveCloudProfile(
    AuthenticatedUser user,
  ) async {
    try {
      final profile = await userProfileRepository!.getById(user.uid);
      final failure = AuthProfileDiagnostics.validate(profile, user.uid);
      if (failure != null) {
        return (
          success: false,
          message: failure,
          profile: null,
        );
      }

      final localAvatar = await loadAvatarPath?.call(user.uid);
      final resolved = profile!.copyWith(
        email: user.email.isEmpty ? profile.email : user.email,
        avatarPath: localAvatar,
      );
      return (success: true, message: null, profile: resolved);
    } catch (error) {
      return (
        success: false,
        message: AuthProfileDiagnostics.readError(error),
        profile: null
      );
    }
  }

  UserModel? _demoAccount(String email) {
    for (final account in _managedUsers) {
      if (account.email.trim().toLowerCase() == email) return account;
    }
    return null;
  }

  Future<void> _cancelProfileListeners() async {
    final profile = _profileSubscription;
    final users = _usersSubscription;
    _profileSubscription = null;
    _usersSubscription = null;
    await profile?.cancel();
    await users?.cancel();
  }

  void _watchCloudProfile(String uid, int revision) {
    _profileSubscription = userProfileRepository!.watchById(uid).listen(
      (profile) {
        if (_disposed ||
            revision != _sessionRevision ||
            _currentUser?.id != uid) {
          return;
        }
        final failure = AuthProfileDiagnostics.validate(profile, uid,
            previouslyActive: true);
        if (failure != null) {
          unawaited(_revokeSession(failure));
          return;
        }
        final wasAdmin = isAdmin;
        _currentUser = profile!.copyWith(avatarPath: _currentUser?.avatarPath);
        if (wasAdmin && !isAdmin) {
          _usersSubscription?.cancel();
          _usersSubscription = null;
          _managedUsers.clear();
        } else if (!wasAdmin && isAdmin) {
          _bindManagedUsers();
        }
        notifyListeners();
      },
      onError: (Object error) {
        if (!_disposed && revision == _sessionRevision) {
          unawaited(_revokeSession(AuthProfileDiagnostics.readError(error)));
        }
      },
    );
  }

  Future<void> _revokeSession(String message) async {
    if (_disposed) return;
    _isRevoking = true;
    ++_sessionRevision;
    _currentUser = null;
    _managedUsers.clear();
    _rememberedSession = false;
    _authError = message;
    notifyListeners();
    await _cancelProfileListeners();
    try {
      await _authenticationService.signOut();
    } catch (_) {
      // Local access is already revoked even when the SDK cannot sign out.
    } finally {
      _isRevoking = false;
      _markAuthReady();
      notifyListeners();
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
    final revision = _sessionRevision;
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
      if (_disposed || revision != _sessionRevision || !isLoggedIn) {
        return (success: false, message: 'Phiên đăng nhập không còn hiệu lực.');
      }
      if (!authResult.isSuccess) {
        return (success: false, message: authResult.message);
      }
      onAvatarPersist?.call(user.id, avatarPath);
      _currentUser = _currentUser!.copyWith(
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
    await _revokeSession('');
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
    if (!isDemoMode ||
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
    if (!isDemoMode) return false;
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
        id: _demoAccount(_email)?.id ?? 'demo-user',
        name: _userName,
        email: _email,
        role: _userRole,
        avatarPath: _avatarPath,
      );

  static String _hash(String password) =>
      sha256.convert(utf8.encode('smart-rice-warehouse::$password')).toString();

  @override
  void dispose() {
    _disposed = true;
    ++_sessionRevision;
    _authSubscription?.cancel();
    _usersSubscription?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }
}

class _NoOpAuthenticationService implements AuthenticationService {
  const _NoOpAuthenticationService();

  @override
  bool get isInitialized => false;

  @override
  AuthenticatedUser? get currentUser => null;

  @override
  Stream<AuthenticatedUser?> get authStateChanges => const Stream.empty();

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async =>
      AuthResult.failure('AuthenticationService chưa được khởi tạo');

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
    required String displayName,
  }) async =>
      AuthResult.failure('AuthenticationService chưa được khởi tạo');

  @override
  Future<AuthResult> sendPasswordResetEmail({required String email}) async =>
      AuthResult.failure('AuthenticationService chưa được khởi tạo');

  @override
  Future<AuthResult> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async =>
      AuthResult.failure('AuthenticationService chưa được khởi tạo');

  @override
  Future<AuthResult> updateDisplayName(String displayName) async =>
      AuthResult.failure('AuthenticationService chưa được khởi tạo');

  @override
  Future<void> signOut() async {}
}
