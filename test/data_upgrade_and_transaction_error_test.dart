import 'package:flutter_test/flutter_test.dart';
import 'package:smart_rice_warehouse/data/local/seed_migration_policy.dart';
import 'package:smart_rice_warehouse/logic/contracts/inventory_transactions.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/customer_model.dart';
import 'package:smart_rice_warehouse/logic/models/damage_report_model.dart';
import 'package:smart_rice_warehouse/logic/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/inventory_check_model.dart';
import 'package:smart_rice_warehouse/logic/models/rice_model.dart';
import 'package:smart_rice_warehouse/logic/models/supplier_model.dart';
import 'package:smart_rice_warehouse/logic/providers/auth_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/damage_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/export_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/import_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/inventory_check_provider.dart';
import 'package:smart_rice_warehouse/logic/view_models/damage_form_view_model.dart';
import 'package:smart_rice_warehouse/logic/view_models/export_form_view_model.dart';
import 'package:smart_rice_warehouse/logic/view_models/import_form_view_model.dart';
import 'package:smart_rice_warehouse/logic/view_models/inventory_check_view_model.dart';

class FailingInventoryTransactions implements InventoryTransactions {
  @override
  Future<void> confirmImportReceipt({
    required ImportReceiptModel receipt,
    required BatchModel batchToCreateOrUpdate,
    required String performedBy,
  }) async {
    throw Exception('Firestore network timeout: Phiếu nhập không thể ghi.');
  }

  @override
  Future<void> confirmExportReceipt({
    required ExportReceiptModel receipt,
    required String performedBy,
  }) async {
    throw Exception(
        'Firestore transaction conflict: Lô hàng đã bị xuất bởi thiết bị khác.');
  }

  @override
  Future<void> confirmDamageReport({
    required DamageReportModel report,
    required String performedBy,
  }) async {
    throw Exception('Permission denied: Không có quyền ghi biên bản báo hỏng.');
  }

  @override
  Future<void> completeInventoryCheck({
    required InventoryCheckSession session,
    required String performedBy,
  }) async {
    throw Exception('Transaction abort: Phiên kiểm kê đã đóng.');
  }
}

void main() {
  group('Backend flag and offline auth isolation', () {
    test(
        'when userProfiles is null, AuthProvider defaults to local offline auth',
        () {
      final authProvider = AuthProvider(
        demoMode: true,
        email: 'admin@gmail.com',
        userProfileRepository: null,
      );

      expect(authProvider.isCloudAuthEnabled, isFalse);
      expect(authProvider.isLoggedIn, isFalse);

      final loginOk = authProvider.login(
        email: 'admin@gmail.com',
        password: 'wrong',
      );
      expect(loginOk, isFalse);

      final validLogin = authProvider.login(
        email: 'admin@gmail.com',
        password: '123456',
      );
      expect(validLogin, isTrue);
      expect(authProvider.isLoggedIn, isTrue);
      expect(authProvider.currentUser?.email, 'admin@gmail.com');
      expect(authProvider.currentUser?.role, 'admin');
    });
  });

  group('Online transaction errors are accurately reported', () {
    final failingTransactions = FailingInventoryTransactions();
    final now = DateTime(2026, 10, 20);

    const sampleRice = RiceModel(
      id: 'rice-test',
      code: 'G-TEST',
      name: 'Gạo Test',
      category: 'Gạo thơm',
      unit: 'kg',
      purchasePrice: 20000,
      sellingPrice: 25000,
      minimumStock: 100,
      description: 'Test',
      isActive: true,
    );

    const sampleSupplier = SupplierModel(
      id: 'sup-test',
      name: 'NCC Test',
      phone: '0901234567',
      email: 'ncc@test.vn',
      address: 'Đồng Tháp',
      taxCode: '1234567890',
      isActive: true,
    );

    const sampleCustomer = CustomerModel(
      id: 'cust-test',
      name: 'Khách Hàng Test',
      phone: '0907654321',
      customerType: CustomerType.retail,
      address: 'TP.HCM',
      isActive: true,
    );

    test('ImportProvider catches online transaction failure and exposes error',
        () async {
      final batchProvider = BatchProvider(initial: []);
      final importProvider = ImportProvider(
        batchProvider,
        initial: [],
        transactionRepository: failingTransactions,
      );

      final vm = ImportFormViewModel();
      addTearDown(vm.dispose);
      vm.setSupplier(sampleSupplier);
      vm.setRice(sampleRice, []);
      vm.setManufactureDate(now);
      vm.setExpiryDate(now.add(const Duration(days: 90)));

      final result = await vm.submitImport(
        importProvider: importProvider,
        quantityText: '500',
        purchasePriceText: '20000',
        batchCodeInput: 'LO-FAIL-01',
      );

      expect(result.success, isFalse);
      expect(result.message, contains('Phiếu nhập không thể ghi'));
      expect(importProvider.errorMessage, contains('Phiếu nhập không thể ghi'));
      expect(importProvider.receipts, isEmpty);
    });

    test('ExportProvider catches online transaction failure and exposes error',
        () async {
      final batch = BatchModel(
        id: 'b-exp',
        code: 'LO-EXP-01',
        riceId: sampleRice.id,
        riceName: sampleRice.name,
        quantity: 1000,
        importDate: now,
        manufactureDate: now,
        expiryDate: now.add(const Duration(days: 90)),
        status: BatchStatus.available,
      );
      final batchProvider = BatchProvider(initial: [batch]);
      final exportProvider = ExportProvider(
        batchProvider,
        initial: [],
        transactionRepository: failingTransactions,
      );

      final vm = ExportFormViewModel();
      addTearDown(vm.dispose);
      vm.setCustomer(sampleCustomer);
      vm.setRice(sampleRice);

      final preview = vm.previewFefo(
        exportProvider: exportProvider,
        batchProvider: batchProvider,
        quantityText: '200',
        sellingPriceText: '25000',
      );
      expect(preview.success, isTrue);

      final result = await vm.confirmExport(
        exportProvider: exportProvider,
      );

      expect(result.success, isFalse);
      expect(result.message, contains('Lô hàng đã bị xuất bởi thiết bị khác'));
      expect(exportProvider.errorMessage,
          contains('Lô hàng đã bị xuất bởi thiết bị khác'));
      expect(exportProvider.receipts, isEmpty);
      // Ensure local batch was not modified on online failure
      expect(batchProvider.findById('b-exp')!.quantity, 1000);
    });

    test('DamageProvider catches online transaction failure and exposes error',
        () async {
      final batch = BatchModel(
        id: 'b-dmg',
        code: 'LO-DMG-01',
        riceId: sampleRice.id,
        riceName: sampleRice.name,
        quantity: 500,
        importDate: now,
        manufactureDate: now,
        expiryDate: now.add(const Duration(days: 90)),
        status: BatchStatus.available,
      );
      final batchProvider = BatchProvider(initial: [batch]);
      final damageProvider = DamageProvider(
        initial: [],
        transactionRepository: failingTransactions,
      );

      final vm = DamageFormViewModel();
      addTearDown(vm.dispose);
      vm.setSelectedBatch(batch);
      vm.setSelectedReason(DamageReason.moc);

      final result = await vm.submit(
        batchProvider: batchProvider,
        damageProvider: damageProvider,
        quantityText: '50',
        note: 'Biên bản thử nghiệm',
      );

      expect(result.success, isFalse);
      expect(result.message, contains('Không có quyền ghi biên bản báo hỏng'));
      expect(damageProvider.errorMessage,
          contains('Không có quyền ghi biên bản báo hỏng'));
      expect(damageProvider.reports, isEmpty);
      expect(batchProvider.findById('b-dmg')!.quantity, 500);
    });

    test(
        'InventoryCheckProvider catches online transaction failure and exposes error',
        () async {
      final batch = BatchModel(
        id: 'b-chk',
        code: 'LO-CHK-01',
        riceId: sampleRice.id,
        riceName: sampleRice.name,
        quantity: 500,
        importDate: now,
        manufactureDate: now,
        expiryDate: now.add(const Duration(days: 90)),
        status: BatchStatus.available,
      );
      final batchProvider = BatchProvider(initial: [batch]);
      final checkProvider = InventoryCheckProvider(
        initial: [],
        transactionRepository: failingTransactions,
      );

      final vm = InventoryCheckViewModel();
      addTearDown(vm.dispose);
      vm.ensureActiveSession(checkProvider: checkProvider);

      vm.saveItemCount(
        checkProvider: checkProvider,
        batch: batch,
        actualQuantityText: '480',
        reason: InventoryCheckReason.haoHut,
      );

      final completeResult = await vm.completeSession(
        checkProvider: checkProvider,
        batchProvider: batchProvider,
      );

      expect(completeResult.success, isFalse);
      expect(completeResult.message, contains('Phiên kiểm kê đã đóng'));
      expect(checkProvider.errorMessage, contains('Phiên kiểm kê đã đóng'));
      expect(checkProvider.history, isEmpty);
      expect(batchProvider.findById('b-chk')!.quantity, 500);
    });
  });

  group('Data upgrade, migration policy and data preservation', () {
    const policy = SeedMigrationPolicy();
    final now = DateTime(2026, 10, 20);

    test(
        'shouldSkipInitialSeedOverwrite protects existing user database without marker version',
        () {
      // Khi installedVersion == 0 nhưng cơ sở dữ liệu đã có dữ liệu thật của người dùng
      final shouldSkip = policy.shouldSkipInitialSeedOverwrite(
        installedVersion: 0,
        hasExistingData: true,
      );
      expect(shouldSkip, isTrue,
          reason:
              'Must never overwrite existing user data when marker is absent');

      // Khi cài đặt mới hoàn toàn (chưa có dữ liệu nào)
      final freshInstallSkip = policy.shouldSkipInitialSeedOverwrite(
        installedVersion: 0,
        hasExistingData: false,
      );
      expect(freshInstallSkip, isFalse,
          reason: 'Fresh database without records should receive initial seed');

      // Khi database đã có version >= 1
      final installedSkip = policy.shouldSkipInitialSeedOverwrite(
        installedVersion: 1,
        hasExistingData: true,
      );
      expect(installedSkip, isFalse);
    });

    test(
        'migrateRicesV1ToV2 supplements sample images while preserving user-created rice records',
        () {
      const sampleRiceWithImage = RiceModel(
        id: 'r-sample-1',
        code: 'ST25',
        name: 'Gạo ST25',
        category: 'Gạo đặc sản',
        unit: 'kg',
        purchasePrice: 20000,
        sellingPrice: 26000,
        minimumStock: 100,
        description: 'Gạo thơm đặc sản',
        imagePath: 'assets/images/rice/st25.png',
        isActive: true,
      );

      const userExistingSampleRiceWithoutImage = RiceModel(
        id: 'r-sample-1',
        code: 'ST25',
        name: 'Gạo ST25',
        category: 'Gạo đặc sản',
        unit: 'kg',
        purchasePrice: 20000,
        sellingPrice: 26000,
        minimumStock: 100,
        description: 'Gạo thơm đặc sản',
        imagePath: null, // Chưa có ảnh ở v1
        isActive: true,
      );

      const userCustomRice = RiceModel(
        id: 'r-user-custom',
        code: 'CUSTOM-01',
        name: 'Gạo Lứt Tự Nhập',
        category: 'Gạo Lứt',
        unit: 'kg',
        purchasePrice: 18000,
        sellingPrice: 24000,
        minimumStock: 50,
        description: 'Gạo lứt đỏ',
        imagePath: 'local_storage/user_custom_rice.jpg',
        isActive: true,
      );

      final existingRices = <RiceModel>[
        userExistingSampleRiceWithoutImage,
        userCustomRice,
      ];

      final sampleRices = <RiceModel>[
        sampleRiceWithImage,
      ];

      final migrated = policy.migrateRicesV1ToV2(
        existingRices: existingRices,
        sampleRices: sampleRices,
      );

      expect(migrated.length, 2);
      // Gạo mẫu được bổ sung ảnh từ sample v2
      expect(migrated[0].id, 'r-sample-1');
      expect(migrated[0].imagePath, 'assets/images/rice/st25.png');

      // Gạo do người dùng tự tạo được giữ nguyên 100% thuộc tính và ảnh
      expect(migrated[1].id, 'r-user-custom');
      expect(migrated[1].imagePath, 'local_storage/user_custom_rice.jpg');
      expect(migrated[1].name, 'Gạo Lứt Tự Nhập');
    });

    test(
        'migrateDamageReportsV2ToV3 preserves user reports and never injects sample reports into history',
        () {
      final sampleReport = DamageReportModel(
        id: 'dmg-sample-01',
        code: 'BH-SAMPLE-01',
        batchId: 'b-sample',
        batchCode: 'LO-SAMPLE',
        riceId: 'r-sample',
        riceName: 'Gạo Mẫu',
        quantity: 10,
        reason: DamageReason.moc,
        createdAt: now.subtract(const Duration(days: 10)),
        createdBy: 'Admin',
        imagePath: 'assets/images/damage/sample_moc.png',
      );

      final userReport1 = DamageReportModel(
        id: 'dmg-user-real-01',
        code: 'BH-REAL-001',
        batchId: 'b-real-1',
        batchCode: 'LO-REAL-01',
        riceId: 'r-real-1',
        riceName: 'Gạo Nàng Hoa Thật',
        quantity: 45,
        reason: DamageReason.baoRach,
        createdAt: now.subtract(const Duration(days: 2)),
        createdBy: 'Kế toán viên',
        imagePath: 'local/user_damage_photo.jpg',
      );

      final existingUserReports = <DamageReportModel>[userReport1];
      final sampleReports = <DamageReportModel>[sampleReport];

      final migrated = policy.migrateDamageReportsV2ToV3(
        existingReports: existingUserReports,
        sampleReports: sampleReports,
      );

      // Quan trọng: Tuyệt đối không xuất hiện sampleReport trong danh sách migrated
      expect(migrated.length, 1);
      expect(migrated.single.id, 'dmg-user-real-01');
      expect(migrated.single.code, 'BH-REAL-001');
      expect(migrated.single.quantity, 45);
      expect(migrated.single.imagePath, 'local/user_damage_photo.jpg');
      expect(
        migrated.any((r) => r.id == 'dmg-sample-01'),
        isFalse,
        reason:
            'Sample damage reports must never be added to real user history',
      );
    });
  });
}
