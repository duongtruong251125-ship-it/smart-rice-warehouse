import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/app.dart';
import 'package:smart_rice_warehouse/data/local/settings_service.dart';
import 'package:smart_rice_warehouse/logic/contracts/authentication_service.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/user_profile_repository.dart';
import 'package:smart_rice_warehouse/logic/models/user_model.dart';
import 'package:smart_rice_warehouse/logic/providers/auth_provider.dart';
import 'package:smart_rice_warehouse/logic/view_models/login_view_model.dart';
import 'package:smart_rice_warehouse/presentation/routes/app_routes.dart';

const identity =
    AuthenticatedUser(uid: 'cloud-admin', email: 'admin@gmail.com');
const activeAdmin = UserModel(
    id: 'cloud-admin',
    name: 'Cloud admin',
    email: 'admin@gmail.com',
    role: 'admin',
    isActive: true);

class TestAuth extends Fake implements AuthenticationService {
  final changes = StreamController<AuthenticatedUser?>.broadcast();
  AuthenticatedUser? user;
  AuthResult? result;
  Object? signInError;
  Completer<AuthResult>? displayNameResult;
  int signOutCount = 0;
  @override
  bool get isInitialized => true;
  @override
  AuthenticatedUser? get currentUser => user;
  @override
  Stream<AuthenticatedUser?> get authStateChanges async* {
    yield user;
    yield* changes.stream;
  }

  void emit(AuthenticatedUser? value) {
    user = value;
    changes.add(value);
  }

  @override
  Future<AuthResult> signIn(
      {required String email, required String password}) async {
    if (signInError != null) throw signInError!;
    final response = result ?? AuthResult.success(identity);
    if (response.isSuccess) emit(response.user);
    return response;
  }

  @override
  Future<void> signOut() async {
    signOutCount++;
    emit(null);
  }

  Future<void> close() => changes.close();
  @override
  Future<AuthResult> updateDisplayName(String name) async =>
      displayNameResult == null
          ? AuthResult.success(user)
          : displayNameResult!.future;
}

class TestProfiles extends Fake implements UserProfileRepository {
  final profiles = <String, UserModel>{activeAdmin.id: activeAdmin};
  final changes = StreamController<UserModel?>.broadcast();
  final allChanges = StreamController<List<UserModel>>.broadcast();
  Object? readError;
  Object? writeError;
  Completer<void>? accessGate;
  Completer<UserModel?>? delayedRead;
  int accessWrites = 0;
  int listSubscriptions = 0;
  @override
  Future<UserModel?> getById(String uid) async {
    if (readError != null) throw readError!;
    return delayedRead == null ? profiles[uid] : delayedRead!.future;
  }

  @override
  Stream<UserModel?> watchById(String uid) async* {
    yield profiles[uid];
    yield* changes.stream;
  }

  @override
  Stream<List<UserModel>> watchAll() async* {
    listSubscriptions++;
    yield profiles.values.toList();
    yield* allChanges.stream;
  }

  void emit(UserModel? profile) {
    if (profile == null) {
      profiles.remove(identity.uid);
    } else {
      profiles[profile.id] = profile;
    }
    changes.add(profile);
  }

  @override
  Future<void> createPendingProfile(
      {required String uid,
      required String email,
      required String displayName}) async {
    profiles[uid] = UserModel(
        id: uid,
        name: displayName,
        email: email,
        role: 'staff',
        isActive: false);
  }

  @override
  Future<void> updateAccess(
      {required String uid,
      required String role,
      required bool isActive}) async {
    accessWrites++;
    await accessGate?.future;
    if (writeError != null) throw writeError!;
    final updated = profiles[uid]!.copyWith(role: role, isActive: isActive);
    profiles[uid] = updated;
    allChanges.add(profiles.values.toList());
    if (uid == identity.uid) changes.add(updated);
  }

  Future<void> close() async {
    await changes.close();
    await allChanges.close();
  }

  @override
  Future<void> updateDisplayName(
      {required String uid, required String displayName}) async {
    profiles[uid] = profiles[uid]!.copyWith(name: displayName);
  }
}

Future<void> flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late TestAuth service;
  late TestProfiles profiles;
  late AuthProvider auth;
  setUp(() {
    service = TestAuth();
    profiles = TestProfiles();
    auth = AuthProvider(
        authenticationService: service, userProfileRepository: profiles);
  });
  tearDown(() async {
    auth.dispose();
    await service.close();
    await profiles.close();
  });

  Future<({bool success, String? message})> signIn() => LoginViewModel(auth)
      .signIn(email: 'admin@gmail.com', password: '123456', remember: true);

  test('sample accounts require explicit demo mode and no cloud repository',
      () async {
    final unconfigured = AuthProvider(rememberedSession: true);
    final demo = AuthProvider(demoMode: true);
    final mixed = AuthProvider(
        demoMode: true,
        authenticationService: service,
        userProfileRepository: profiles);
    addTearDown(unconfigured.dispose);
    addTearDown(demo.dispose);
    addTearDown(mixed.dispose);
    expect(unconfigured.isLoggedIn, isFalse);
    expect(unconfigured.isAdmin, isFalse);
    expect(unconfigured.login(email: 'admin@gmail.com', password: '123456'),
        isFalse);
    expect(demo.login(email: 'admin@gmail.com', password: '123456'), isTrue);
    expect(mixed.isDemoMode, isFalse);
    expect(mixed.login(email: 'admin@gmail.com', password: '123456'), isFalse);
  });

  test('bad cloud password cannot fall back to known demo credentials',
      () async {
    await flush();
    service.result = AuthResult.failure('wrong-password');
    expect((await signIn()).success, isFalse);
    expect(auth.isLoggedIn, isFalse);
    expect(auth.login(email: 'admin@gmail.com', password: '123456'), isFalse);
  });

  test('network errors and profile read failures fail closed', () async {
    await flush();
    service.signInError = Exception('network-request-failed');
    expect((await signIn()).success, isFalse);
    service.signInError = null;
    profiles.readError = Exception('Firestore unavailable');
    expect((await signIn()).success, isFalse);
    expect(auth.isLoggedIn, isFalse);
    expect(auth.managedUsers, isEmpty);
  });

  test(
      'inactive or pending profile matching demo email cannot be activated locally',
      () async {
    await flush();
    profiles.profiles[identity.uid] =
        activeAdmin.copyWith(role: 'staff', isActive: false);
    expect((await signIn()).success, isFalse);
    expect(auth.isAdmin, isFalse);
    expect(service.signOutCount, greaterThan(0));
  });

  test('missing cloud profile is denied without creating a profile', () async {
    await flush();
    profiles.profiles.clear();
    expect((await signIn()).success, isFalse);
    expect(profiles.profiles, isEmpty);
    expect(auth.authError, contains('Không tìm thấy hồ sơ'));
  });

  test('Firestore staff role wins over matching demo admin email', () async {
    await flush();
    profiles.profiles[identity.uid] = activeAdmin.copyWith(role: 'staff');
    expect((await signIn()).success, isTrue);
    await flush();
    expect(auth.isStaff, isTrue);
    expect(auth.isAdmin, isFalse);
    expect(profiles.listSubscriptions, 0);
    expect(auth.managedUsers, isEmpty);
  });

  test(
      'restored Firebase session revalidates profile and ignores remembered local admin',
      () async {
    await flush();
    service.emit(identity);
    await flush();
    expect(auth.currentUser?.id, identity.uid);
    expect(auth.isAdmin, isTrue);
    profiles.emit(activeAdmin.copyWith(isActive: false));
    await flush();
    expect(auth.isLoggedIn, isFalse);
    expect(service.signOutCount, greaterThan(0));
    service.emit(identity);
    await flush();
    expect(auth.isLoggedIn, isFalse);
  });

  test('live demotion removes admin state and live deletion revokes session',
      () async {
    await flush();
    expect((await signIn()).success, isTrue);
    await flush();
    expect(auth.managedUsers.map((u) => u.id), [identity.uid]);
    profiles.emit(activeAdmin.copyWith(role: 'staff'));
    await flush();
    expect(auth.isStaff, isTrue);
    expect(auth.managedUsers, isEmpty);
    profiles.emit(null);
    await flush();
    expect(auth.isLoggedIn, isFalse);
  });

  test('profile listener error revokes access', () async {
    await flush();
    await signIn();
    await flush();
    profiles.changes.addError(Exception('permission-denied'));
    await flush();
    expect(auth.isLoggedIn, isFalse);
  });

  test('failed updateAccess leaves local permissions unchanged', () async {
    await flush();
    await signIn();
    await flush();
    profiles.writeError = Exception('permission-denied');
    final result = await auth.updateUserAccess(
        uid: identity.uid, role: 'staff', isActive: false);
    expect(result.success, isFalse);
    expect(result.message, contains('permission-denied'));
    expect(auth.isAdmin, isTrue);
    expect(auth.managedUsers.single.isActive, isTrue);
    expect(auth.managedUsers.single.role, 'admin');
  });

  test('staff cannot update roles and successful admin update waits for server',
      () async {
    await flush();
    await signIn();
    await flush();
    profiles.accessGate = Completer<void>();
    final update =
        auth.updateUserAccess(uid: identity.uid, role: 'staff', isActive: true);
    await flush();
    expect(auth.isAdmin, isTrue);
    expect(auth.managedUsers.single.role, 'admin');
    profiles.accessGate!.complete();
    expect((await update).success, isTrue);
    await flush();
    final writes = profiles.accessWrites;
    expect(
        (await auth.updateUserAccess(
                uid: identity.uid, role: 'admin', isActive: true))
            .success,
        isFalse);
    expect(profiles.accessWrites, writes);
  });

  test('slow session restoration cannot resurrect a signed-out session',
      () async {
    await flush();
    profiles.delayedRead = Completer<UserModel?>();
    service.emit(identity);
    await flush();
    await auth.logoutWithFirebase();
    profiles.delayedRead!.complete(activeAdmin);
    await flush();
    expect(auth.isLoggedIn, isFalse);
  });

  test(
      'a blocked restored profile cannot use remembered local admin permissions',
      () async {
    await flush();
    auth.dispose();
    profiles.profiles[identity.uid] = activeAdmin.copyWith(isActive: false);
    service.user = identity;
    auth = AuthProvider(
        authenticationService: service,
        userProfileRepository: profiles,
        rememberedSession: true,
        userName: 'Local admin',
        userRole: 'admin');
    await auth.waitUntilReady();
    expect(auth.isLoggedIn, isFalse);
    expect(auth.isAdmin, isFalse);
    expect(service.signOutCount, 1);
  });

  test('an in-flight profile edit cannot resurrect a blocked session',
      () async {
    await flush();
    await signIn();
    await flush();
    service.displayNameResult = Completer<AuthResult>();
    final update = auth.updateProfileWithFirebase(name: 'Updated');
    await flush();
    profiles.emit(activeAdmin.copyWith(isActive: false));
    await flush();
    service.displayNameResult!.complete(AuthResult.success(identity));
    expect((await update).success, isFalse);
    expect(auth.isLoggedIn, isFalse);
  });

  testWidgets('cloud demo shortcuts stay hidden', (tester) async {
    await tester.pumpWidget(SmartRiceWarehouseApp(
        settings: SettingsService(),
        authenticationService: service,
        userProfiles: profiles));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Tài khoản mẫu (chế độ demo):'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  test('an in-flight profile edit preserves a server-side role demotion',
      () async {
    await flush();
    await signIn();
    await flush();
    service.displayNameResult = Completer<AuthResult>();
    final update = auth.updateProfileWithFirebase(name: 'Updated');
    await flush();
    profiles.emit(activeAdmin.copyWith(role: 'staff'));
    await flush();
    service.displayNameResult!.complete(AuthResult.success(identity));
    expect((await update).success, isTrue);
    expect(auth.isStaff, isTrue);
    expect(auth.isAdmin, isFalse);
  });

  testWidgets(
      'revocation removes protected routes and cloud UI hides demo shortcuts',
      (tester) async {
    await tester.pumpWidget(SmartRiceWarehouseApp(
        settings: SettingsService(),
        authenticationService: service,
        userProfiles: profiles));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Tài khoản mẫu (chế độ demo):'), findsNothing);
    final context = tester.element(find.byType(TextFormField).first);
    final appAuth = context.read<AuthProvider>();
    await appAuth.loginWithFirebase(
        email: 'admin@gmail.com', password: 'cloud-password');
    AppRoutes.navigatorKey.currentState!
        .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    await tester.pumpAndSettle();
    final close = find.widgetWithText(TextButton, 'Đóng');
    if (close.evaluate().isNotEmpty) {
      await tester.tap(close);
      await tester.pumpAndSettle();
    }
    AppRoutes.navigatorKey.currentState!.pushNamed(AppRoutes.rice);
    await tester.pumpAndSettle();
    profiles.emit(activeAdmin.copyWith(isActive: false));
    await tester.pumpAndSettle();
    expect(appAuth.isLoggedIn, isFalse);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(AppRoutes.navigatorKey.currentState!.canPop(), isFalse);
    AppRoutes.navigatorKey.currentState!.pushNamed(AppRoutes.inventory);
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
