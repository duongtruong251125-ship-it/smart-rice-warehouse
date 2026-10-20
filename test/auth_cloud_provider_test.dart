import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_rice_warehouse/data/firebase/firebase_auth_service.dart';
import 'package:smart_rice_warehouse/logic/models/user_model.dart';
import 'package:smart_rice_warehouse/logic/providers/auth_provider.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/user_profile_repository.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/user_profile_mapper.dart';

void main() {
  group('cloud authentication session', () {
    test('restores an active Firestore profile and local avatar by uid',
        () async {
      final auth = _FakeAuthenticationService();
      final profiles = _FakeUserProfileRepository()
        ..profiles['uid-1'] = const UserModel(
          id: 'uid-1',
          name: 'Quản trị kho',
          email: 'admin@example.com',
          role: 'admin',
          isActive: true,
        );
      final provider = AuthProvider(
        authenticationService: auth,
        userProfileRepository: profiles,
        loadAvatarPath: (uid) async => 'avatars/$uid.jpg',
      );

      auth.emit(
        const AuthenticatedUser(
          uid: 'uid-1',
          email: 'admin@example.com',
        ),
      );
      await provider.waitUntilReady();

      expect(provider.isLoggedIn, isTrue);
      expect(provider.currentUser!.id, 'uid-1');
      expect(provider.currentUser!.role, 'admin');
      expect(provider.currentUser!.avatarPath, 'avatars/uid-1.jpg');
      provider.dispose();
      await auth.close();
    });

    test('rejects and signs out an inactive profile', () async {
      final auth = _FakeAuthenticationService();
      final profiles = _FakeUserProfileRepository()
        ..profiles['uid-2'] = const UserModel(
          id: 'uid-2',
          name: 'Nhân viên mới',
          email: 'staff@example.com',
          role: 'staff',
          isActive: false,
        );
      final provider = AuthProvider(
        authenticationService: auth,
        userProfileRepository: profiles,
      );

      auth.emit(
        const AuthenticatedUser(
          uid: 'uid-2',
          email: 'staff@example.com',
        ),
      );
      await provider.waitUntilReady();

      expect(provider.isLoggedIn, isFalse);
      expect(
          provider.authError, contains('chưa được kích hoạt hoặc đã bị khóa'));
      expect(auth.signOutCount, 1);
      provider.dispose();
      await auth.close();
    });

    test('registration always creates a pending staff profile', () async {
      final auth = _FakeAuthenticationService()
        ..registerResult = FirebaseAuthResult.success(
          const AuthenticatedUser(
            uid: 'uid-new',
            email: 'new@example.com',
            displayName: 'Người dùng mới',
          ),
        );
      final profiles = _FakeUserProfileRepository();
      final provider = AuthProvider(
        authenticationService: auth,
        userProfileRepository: profiles,
      );

      final result = await provider.registerWithFirebase(
        email: 'new@example.com',
        password: 'secret123',
        name: 'Người dùng mới',
        role: 'admin',
      );

      expect(result.success, isTrue);
      expect(profiles.profiles['uid-new']!.role, 'staff');
      expect(profiles.profiles['uid-new']!.isActive, isFalse);
      expect(auth.signOutCount, 1);
      expect(provider.isLoggedIn, isFalse);
      provider.dispose();
      await auth.close();
    });
  });

  test('user profile mapper never serializes a local avatar path', () {
    const mapper = UserProfileMapper();
    final data = mapper.toFirestore(
      const UserModel(
        id: 'uid-1',
        name: 'Admin',
        email: 'ADMIN@example.com',
        role: 'admin',
        avatarPath: r'C:\device\avatar.jpg',
      ),
      null,
    );

    expect(data['email'], 'admin@example.com');
    expect(data.containsKey('avatarPath'), isFalse);
  });
}

class _FakeAuthenticationService implements AuthenticationService {
  final StreamController<AuthenticatedUser?> _controller =
      StreamController<AuthenticatedUser?>.broadcast();

  FirebaseAuthResult? signInResult;
  FirebaseAuthResult? registerResult;
  AuthenticatedUser? _currentUser;
  int signOutCount = 0;

  void emit(AuthenticatedUser? user) {
    _currentUser = user;
    _controller.add(user);
  }

  Future<void> close() => _controller.close();

  @override
  Stream<AuthenticatedUser?> get authStateChanges => _controller.stream;

  @override
  AuthenticatedUser? get currentUser => _currentUser;

  @override
  bool get isInitialized => true;

  @override
  Future<FirebaseAuthResult> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return registerResult ?? FirebaseAuthResult.failure('missing fake result');
  }

  @override
  Future<FirebaseAuthResult> sendPasswordResetEmail({
    required String email,
  }) async {
    return FirebaseAuthResult.success();
  }

  @override
  Future<FirebaseAuthResult> signIn({
    required String email,
    required String password,
  }) async {
    return signInResult ?? FirebaseAuthResult.failure('missing fake result');
  }

  @override
  Future<void> signOut() async {
    signOutCount++;
    _currentUser = null;
  }

  @override
  Future<FirebaseAuthResult> updateDisplayName(String displayName) async {
    return FirebaseAuthResult.success(_currentUser);
  }

  @override
  Future<FirebaseAuthResult> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return FirebaseAuthResult.success(_currentUser);
  }
}

class _FakeUserProfileRepository implements UserProfileRepository {
  final Map<String, UserModel> profiles = {};

  @override
  Stream<List<UserModel>> watchAll() => Stream.value(profiles.values.toList());

  @override
  Future<void> createPendingProfile({
    required String uid,
    required String email,
    required String displayName,
  }) async {
    profiles[uid] = UserModel(
      id: uid,
      name: displayName,
      email: email,
      role: 'staff',
      isActive: false,
    );
  }

  @override
  Future<UserModel?> getById(String uid) async => profiles[uid];

  @override
  Future<void> updateDisplayName({
    required String uid,
    required String displayName,
  }) async {
    final profile = profiles[uid];
    if (profile != null) profiles[uid] = profile.copyWith(name: displayName);
  }

  @override
  Future<void> updateAccess({
    required String uid,
    required String role,
    required bool isActive,
  }) async {
    final profile = profiles[uid];
    if (profile != null) {
      profiles[uid] = profile.copyWith(role: role, isActive: isActive);
    }
  }

  @override
  Stream<UserModel?> watchById(String uid) => Stream.value(profiles[uid]);
}
