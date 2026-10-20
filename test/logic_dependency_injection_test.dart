import 'package:flutter_test/flutter_test.dart';
import 'package:smart_rice_warehouse/logic/contracts/authentication_service.dart';
import 'package:smart_rice_warehouse/logic/contracts/initial_data_provider.dart';
import 'package:smart_rice_warehouse/logic/contracts/media_storage.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/user_profile_repository.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/customer_model.dart';
import 'package:smart_rice_warehouse/logic/models/damage_report_model.dart';
import 'package:smart_rice_warehouse/logic/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/inventory_check_model.dart';
import 'package:smart_rice_warehouse/logic/models/rice_characteristic_model.dart';
import 'package:smart_rice_warehouse/logic/models/rice_model.dart';
import 'package:smart_rice_warehouse/logic/models/supplier_model.dart';
import 'package:smart_rice_warehouse/logic/models/user_model.dart';
import 'package:smart_rice_warehouse/logic/models/warehouse_location_model.dart';
import 'package:smart_rice_warehouse/logic/providers/auth_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/logic/services/media_service.dart';

class FakeAuthService implements AuthenticationService {
  @override
  bool isInitialized = true;

  AuthenticatedUser? _user;
  bool shouldFailSignIn = false;
  bool shouldFailChangePassword = false;

  @override
  AuthenticatedUser? get currentUser => _user;

  @override
  Stream<AuthenticatedUser?> get authStateChanges =>
      Stream<AuthenticatedUser?>.value(_user);

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    if (shouldFailSignIn) {
      return AuthResult.failure('Invalid credentials');
    }
    _user = AuthenticatedUser(uid: 'fake-uid-123', email: email);
    return AuthResult.success(_user);
  }

  @override
  Future<void> signOut() async {
    _user = null;
  }

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final user = AuthenticatedUser(
      uid: 'fake-uid-reg',
      email: email,
      displayName: displayName,
    );
    return AuthResult.success(user);
  }

  @override
  Future<AuthResult> sendPasswordResetEmail({required String email}) async {
    return AuthResult.success();
  }

  @override
  Future<AuthResult> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (shouldFailChangePassword) {
      return AuthResult.failure('Mật khẩu hiện tại không đúng');
    }
    return AuthResult.success();
  }

  @override
  Future<AuthResult> updateDisplayName(String displayName) async {
    return AuthResult.success();
  }
}

class FakeUserProfileRepository implements UserProfileRepository {
  final Map<String, UserModel> profiles = {};

  @override
  Future<UserModel?> getById(String uid) async => profiles[uid];

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
      role: 'admin',
      isActive: true,
    );
  }

  @override
  Future<void> updateDisplayName({
    required String uid,
    required String displayName,
  }) async {
    final existing = profiles[uid];
    if (existing != null) {
      profiles[uid] = existing.copyWith(name: displayName);
    }
  }

  @override
  Future<void> updateAccess({
    required String uid,
    required String role,
    required bool isActive,
  }) async {
    final existing = profiles[uid];
    if (existing != null) {
      profiles[uid] = existing.copyWith(role: role, isActive: isActive);
    }
  }

  @override
  Stream<List<UserModel>> watchAll() => Stream.value(profiles.values.toList());

  @override
  Stream<UserModel?> watchById(String uid) => Stream.value(profiles[uid]);
}

class FakeMediaStorage implements MediaStorage {
  final Map<String, String> savedFiles = {};
  final List<String> deletedPaths = [];

  @override
  Future<String?> saveImagePermanently(
    String? sourcePath, {
    required String subDirectory,
    String? oldPathToDelete,
  }) async {
    if (sourcePath == null) return null;
    final destination = '/fake_storage/$subDirectory/fake_image.png';
    savedFiles[destination] = sourcePath;
    if (oldPathToDelete != null) {
      deletedPaths.add(oldPathToDelete);
      savedFiles.remove(oldPathToDelete);
    }
    return destination;
  }

  @override
  Future<bool> deleteImageIfExists(String? path) async {
    if (path != null) {
      deletedPaths.add(path);
      savedFiles.remove(path);
      return true;
    }
    return false;
  }
}

class FakeInitialDataProvider implements InitialDataProvider {
  @override
  List<RiceModel> get rices => const [
        RiceModel(
          id: 'rice-fake-1',
          code: 'G-FAKE',
          name: 'Gạo Giả Lập Test',
          category: 'Gạo Thơm',
          unit: 'kg',
          purchasePrice: 12000,
          sellingPrice: 15000,
          minimumStock: 100,
          description: 'Dành cho test DI',
          isActive: true,
        ),
      ];

  @override
  List<BatchModel> get batches => const [];

  @override
  List<CustomerModel> get customers => const [];

  @override
  List<DamageReportModel> get damageReports => const [];

  @override
  List<ExportReceiptModel> get exportReceipts => const [];

  @override
  List<ImportReceiptModel> get importReceipts => const [];

  @override
  List<InventoryCheckSession> get inventoryChecks => const [];

  @override
  List<RiceCharacteristicModel> get riceCharacteristics => const [];

  @override
  List<SupplierModel> get suppliers => const [];

  @override
  List<WarehouseLocationModel> get warehouseLocations => const [];
}

void main() {
  group('Logic Dependency Injection Tests', () {
    test('AuthProvider interacts cleanly with injected contracts', () async {
      final fakeAuth = FakeAuthService();
      final fakeRepo = FakeUserProfileRepository();
      fakeRepo.profiles['fake-uid-123'] = const UserModel(
        id: 'fake-uid-123',
        name: 'Test Admin',
        email: 'test@smartrice.vn',
        role: 'admin',
        isActive: true,
      );

      final authProvider = AuthProvider(
        authenticationService: fakeAuth,
        userProfileRepository: fakeRepo,
      );

      await authProvider.waitUntilReady();
      expect(authProvider.isLoggedIn, isFalse);

      final loginResult = await authProvider.loginWithFirebase(
        email: 'test@smartrice.vn',
        password: 'password123',
      );
      expect(loginResult.success, isTrue);
      expect(authProvider.isLoggedIn, isTrue);
      expect(authProvider.currentUser?.id, equals('fake-uid-123'));
      expect(authProvider.currentUser?.email, equals('test@smartrice.vn'));

      final changePassSuccess = await authProvider.changePasswordWithFirebase(
        current: 'old-pass',
        replacement: 'new-pass',
      );
      expect(changePassSuccess.success, isTrue);

      fakeAuth.shouldFailChangePassword = true;
      final changePassFail = await authProvider.changePasswordWithFirebase(
        current: 'wrong',
        replacement: 'new',
      );
      expect(changePassFail.success, isFalse);
      expect(changePassFail.message, contains('Mật khẩu'));

      await authProvider.logoutWithFirebase();
      expect(authProvider.isLoggedIn, isFalse);
      expect(authProvider.currentUser, isNull);
    });

    test('MediaService operates via injected MediaStorage contract', () async {
      final fakeStorage = FakeMediaStorage();
      MediaService.initialize(fakeStorage);

      const sourcePath = 'fake/path/avatar.png';
      final savedPath = await MediaService.save(
        sourcePath,
        subDirectory: 'avatars',
      );

      expect(savedPath, equals('/fake_storage/avatars/fake_image.png'));
      expect(fakeStorage.savedFiles.containsKey(savedPath), isTrue);

      final deleted = await MediaService.delete(savedPath);
      expect(deleted, isTrue);
      expect(fakeStorage.deletedPaths, contains(savedPath));
      expect(fakeStorage.savedFiles.containsKey(savedPath), isFalse);
    });

    test(
        'RiceProvider loads from DefaultDataRegistry without data layer dependency',
        () {
      DefaultDataRegistry.provider = FakeInitialDataProvider();

      final provider = RiceProvider();
      expect(provider.rices.length, equals(1));
      expect(provider.rices.first.code, equals('G-FAKE'));
      expect(provider.rices.first.name, equals('Gạo Giả Lập Test'));
    });
  });
}
