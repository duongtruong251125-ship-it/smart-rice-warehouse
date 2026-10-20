import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/user_profile_mapper.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/repository_exception.dart';
import 'package:smart_rice_warehouse/logic/models/user_model.dart';
import 'package:smart_rice_warehouse/logic/providers/auth_provider.dart';
import 'package:smart_rice_warehouse/logic/services/auth_profile_diagnostics.dart';
import 'package:smart_rice_warehouse/logic/view_models/login_view_model.dart';
import 'package:smart_rice_warehouse/presentation/screens/auth/login_screen.dart';
import 'package:smart_rice_warehouse/presentation/routes/app_routes.dart';
import 'auth_security_regression_test.dart'
    show TestAuth, TestProfiles, identity, activeAdmin, flush;

class RawProfiles extends TestProfiles {
  Map<String, dynamic>? raw;
  int pendingWrites = 0;
  @override
  Future<UserModel?> getById(String uid) async => raw == null
      ? super.getById(uid)
      : const UserProfileMapper().fromMap(uid, raw!);
  @override
  Future<void> createPendingProfile(
      {required String uid,
      required String email,
      required String displayName}) async {
    pendingWrites++;
  }
}

void main() {
  late TestAuth service;
  late RawProfiles profiles;
  late AuthProvider auth;
  setUp(() {
    service = TestAuth();
    profiles = RawProfiles();
    auth = AuthProvider(
        authenticationService: service, userProfileRepository: profiles);
  });
  tearDown(() async {
    auth.dispose();
    await service.close();
    await profiles.close();
  });
  Future<({bool success, String? message})> signIn() => LoginViewModel(auth)
      .signIn(email: identity.email, password: '123456', remember: false);

  for (final role in <Object?>[
    'admin\n',
    ' admin',
    'admin ',
    'staff\t',
    '',
    'owner',
    1,
    true,
    null
  ]) {
    test(
        'rejects exact malformed role ${role.runtimeType}: ${role.toString().replaceAll('\n', '\\n')}',
        () async {
      await flush();
      profiles.raw = {'role': role, 'isActive': true};
      final result = await signIn();
      expect(result.success, false);
      expect(result.message, AuthProfileDiagnostics.invalidRole);
      expect(auth.isLoggedIn, false);
      expect(profiles.pendingWrites, 0);
    });
  }
  test('missing role does not default to staff', () async {
    await flush();
    profiles.raw = {'isActive': true};
    expect((await signIn()).message, AuthProfileDiagnostics.invalidRole);
  });
  test('valid raw admin profile is accepted without normalization', () async {
    await flush();
    profiles.raw = {'role': 'admin', 'isActive': true};
    expect((await signIn()).success, true);
    expect(auth.isAdmin, true);
    expect(profiles.pendingWrites, 0);
  });
  test('restoration rejects malformed role without writes', () async {
    await flush();
    profiles.raw = {'role': 'admin\n', 'isActive': true};
    service.emit(identity);
    await flush();
    expect(auth.isLoggedIn, false);
    expect(auth.authError, AuthProfileDiagnostics.invalidRole);
    expect(profiles.pendingWrites, 0);
  });
  test('live malformed role revokes a previously valid session', () async {
    await flush();
    expect((await signIn()).success, true);
    await flush();
    profiles.emit(activeAdmin.copyWith(role: 'admin\n'));
    await flush();
    expect(auth.isLoggedIn, false);
    expect(auth.authError, AuthProfileDiagnostics.invalidRole);
  });
  for (final active in <Object?>[null, 'true', 1]) {
    test('invalid active status $active is not pending', () async {
      await flush();
      profiles.raw = {'role': 'admin', 'isActive': active};
      expect((await signIn()).message, AuthProfileDiagnostics.invalidData);
    });
  }
  test('UID mismatch is distinct from inactive', () async {
    await flush();
    profiles.profiles[identity.uid] = const UserModel(
        id: 'other', name: 'Other', email: 'other@example.com', role: 'admin');
    expect((await signIn()).message, contains('không khớp UID'));
    expect(auth.isLoggedIn, false);
  });
  test('missing profile stays read-only on login and session restoration',
      () async {
    await flush();
    profiles.profiles.clear();
    expect((await signIn()).message, contains('Không tìm thấy hồ sơ'));
    service.emit(identity);
    await flush();
    expect(auth.isLoggedIn, false);
    expect(profiles.pendingWrites, 0);
    expect(profiles.profiles, isEmpty);
  });
  test('pending denied; active admin allowed; live lock revokes', () async {
    await flush();
    profiles.profiles[identity.uid] = activeAdmin.copyWith(isActive: false);
    expect((await signIn()).message,
        contains('chưa được kích hoạt hoặc đã bị khóa'));
    profiles.profiles[identity.uid] = activeAdmin;
    expect((await signIn()).success, true);
    await flush();
    expect(auth.isAdmin, true);
    profiles.emit(activeAdmin.copyWith(isActive: false));
    await flush();
    expect(auth.isLoggedIn, false);
    expect(auth.authError, startsWith('Tài khoản đã bị khóa.'));
  });
  for (final entry in {
    'unavailable': 'lỗi kết nối',
    'deadline-exceeded': 'lỗi kết nối',
    'permission-denied': 'Không có quyền đọc',
    'unverified-profile': 'Chưa xác minh'
  }.entries) {
    test('safe ${entry.key} message through LoginViewModel', () async {
      await flush();
      profiles.readError =
          RepositoryException('private-marker', code: entry.key);
      final result = await signIn();
      expect(result.message, contains(entry.value));
      expect(result.message, isNot(contains('private-marker')));
      expect(auth.isLoggedIn, false);
    });
  }
  test('listener errors are safe and revoke session', () async {
    await flush();
    expect((await signIn()).success, true);
    await flush();
    profiles.changes.addError(
        const RepositoryException('private-marker', code: 'permission-denied'));
    await flush();
    expect(auth.isLoggedIn, false);
    expect(auth.authError, contains('Không có quyền đọc'));
    expect(auth.authError, isNot(contains('private-marker')));
  });
  for (final invalidRole in [true, false]) {
    testWidgets(
        'LoginScreen shows correct ${invalidRole ? 'role' : 'network'} diagnostic',
        (tester) async {
      if (invalidRole) {
        profiles.raw = {'role': 'admin\n', 'isActive': true};
      } else {
        profiles.readError =
            const RepositoryException('private-marker', code: 'unavailable');
      }
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: ToastificationWrapper(
              child: MaterialApp(
                  navigatorKey: AppRoutes.navigatorKey,
                  home: const LoginScreen()))));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), identity.email);
      await tester.enterText(find.byType(TextFormField).at(1), '123456');
      await tester
          .ensureVisible(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await tester.runAsync(() async {
        await flush();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      expect(
          auth.authError,
          invalidRole
              ? AuthProfileDiagnostics.invalidRole
              : contains('lỗi kết nối'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(
          find.text(invalidRole
              ? AuthProfileDiagnostics.invalidRole
              : AuthProfileDiagnostics.readError(
                  const RepositoryException('', code: 'unavailable'))),
          findsOneWidget);
      expect(find.textContaining('private-marker'), findsNothing);
      expect(auth.isLoggedIn, false);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
