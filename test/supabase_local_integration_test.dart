import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_rice_warehouse/data/repositories/supabase/supabase_auth_service.dart';
import 'package:smart_rice_warehouse/data/repositories/supabase/supabase_domain_repositories.dart';
import 'package:smart_rice_warehouse/data/repositories/supabase/supabase_inventory_transactions.dart';
import 'package:smart_rice_warehouse/data/repositories/supabase/supabase_user_profile_repository.dart';
import 'package:smart_rice_warehouse/logic/models/batch_allocation_model.dart';
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

class _MemoryPkceStorage extends GotrueAsyncStorage {
  _MemoryPkceStorage();

  final Map<String, String> _values = {};

  @override
  Future<String?> getItem({required String key}) async => _values[key];

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }
}

class _NetworkEnabledTestBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _NetworkEnabledTestBinding();
  TestWidgetsFlutterBinding.ensureInitialized();
  final enabled = Platform.environment['RUN_SUPABASE_LOCAL_TESTS'] == '1';

  test(
    'local Supabase auth, RLS repositories, realtime and inventory RPCs round-trip',
    () async {
      final url = Platform.environment['SUPABASE_URL']!;
      final key = Platform.environment['SUPABASE_PUBLISHABLE_KEY']!;
      final email = Platform.environment['SUPABASE_TEST_EMAIL']!;
      final password = Platform.environment['SUPABASE_TEST_PASSWORD']!;
      await Supabase.initialize(
        url: url,
        publishableKey: key,
        authOptions: FlutterAuthClientOptions(
          localStorage: const EmptyLocalStorage(),
          persistSession: false,
          pkceAsyncStorage: _MemoryPkceStorage(),
        ),
      );
      final client = Supabase.instance.client;
      final auth = SupabaseAuthService(client: client);
      final signedIn = await auth.signIn(email: email, password: password);
      expect(signedIn.isSuccess, isTrue, reason: signedIn.message);
      final uid = signedIn.user!.uid;

      final profiles = SupabaseUserProfileRepository(client: client);
      final profile = await profiles.getById(uid);
      expect(profile?.role, 'admin');
      expect(profile?.isActive, isTrue);

      final profileSnapshot = Completer<List<UserModel>>();
      final profileSubscription = profiles.watchAll().listen(
        (rows) {
          if (!profileSnapshot.isCompleted) profileSnapshot.complete(rows);
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!profileSnapshot.isCompleted) {
            profileSnapshot.completeError(error, stackTrace);
          }
        },
      );
      final profilesForAdmin = await profileSnapshot.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException(
          'Supabase profile stream did not provide its initial snapshot.',
        ),
      );
      expect(profilesForAdmin.any((row) => row.id == uid), isTrue);
      await profileSubscription.cancel();

      final suffix = DateTime.now().microsecondsSinceEpoch.toString();
      final supplierId = 'it-supplier-$suffix';
      final supplierRepository = supabaseSuppliers(client: client);
      final supplier = SupplierModel(
        id: supplierId,
        name: 'Integration supplier $suffix',
        phone: '',
        email: '',
        address: '',
        taxCode: '',
        isActive: true,
      );
      await supplierRepository.create(supplierId, supplier);
      expect(
          (await supplierRepository.getById(supplierId))?.name, supplier.name);
      final updatedSupplierName = 'Updated integration supplier $suffix';
      final firstSupplierSnapshot = Completer<List<SupplierModel>>();
      final realtimeSupplierUpdate = Completer<void>();
      final supplierSubscription = supplierRepository.watchAll().listen(
        (rows) {
          if (!firstSupplierSnapshot.isCompleted) {
            firstSupplierSnapshot.complete(rows);
          }
          if (rows.any((row) =>
                  row.id == supplierId && row.name == updatedSupplierName) &&
              !realtimeSupplierUpdate.isCompleted) {
            realtimeSupplierUpdate.complete();
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!firstSupplierSnapshot.isCompleted) {
            firstSupplierSnapshot.completeError(error, stackTrace);
          }
          if (!realtimeSupplierUpdate.isCompleted) {
            realtimeSupplierUpdate.completeError(error, stackTrace);
          }
        },
      );
      await firstSupplierSnapshot.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException(
          'Supabase supplier stream did not provide its initial snapshot.',
        ),
      );
      await supplierRepository.update(
        supplierId,
        supplier.copyWith(name: updatedSupplierName),
      );
      await realtimeSupplierUpdate.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException(
          'Supabase supplier stream did not report the updated row.',
        ),
      );
      await supplierSubscription.cancel();
      expect((await supplierRepository.getById(supplierId))?.name,
          updatedSupplierName);

      final characteristicId = 'it-characteristic-$suffix';
      final characteristics = supabaseRiceCharacteristics(client: client);
      await characteristics.create(
        characteristicId,
        RiceCharacteristicModel(
          id: characteristicId,
          name: 'Integration characteristic $suffix',
          colorValue: 0xff0d9488,
        ),
      );

      final riceId = 'it-rice-$suffix';
      final riceRepository = supabaseRiceProducts(client: client);
      final rice = RiceModel(
        id: riceId,
        code: 'IT-$suffix',
        name: 'Integration rice $suffix',
        category: 'jasmine',
        unit: 'kg',
        purchasePrice: 10.5,
        sellingPrice: 15,
        minimumStock: 10,
        description: '',
        isActive: true,
        characteristicIds: [characteristicId],
      );
      await riceRepository.create(riceId, rice);
      expect((await riceRepository.getById(riceId))?.characteristicIds,
          [characteristicId]);

      final customerId = 'it-customer-$suffix';
      final customerRepository = supabaseCustomers(client: client);
      await customerRepository.create(
        customerId,
        CustomerModel(
          id: customerId,
          name: 'Integration customer $suffix',
          phone: '',
          customerType: CustomerType.retail,
          address: '',
          isActive: true,
        ),
      );

      final locationId = 'it-location-$suffix';
      final locationRepository = supabaseWarehouseLocations(client: client);
      await locationRepository.create(
        locationId,
        WarehouseLocationModel(
          id: locationId,
          zone: 'Test zone',
          rack: 'Test rack',
          shelf: 'Test shelf',
          code: 'IT-LOC-$suffix',
          capacity: 1000,
        ),
      );
      expect(
          (await locationRepository.getById(locationId))?.currentBatchCount, 0);
      final locationCountUpdated = Completer<void>();
      final locationSubscription = locationRepository.watchAll().listen(
        (rows) {
          final location = rows.where((row) => row.id == locationId);
          if (location.isNotEmpty &&
              location.single.currentBatchCount == 1 &&
              !locationCountUpdated.isCompleted) {
            locationCountUpdated.complete();
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!locationCountUpdated.isCompleted) {
            locationCountUpdated.completeError(error, stackTrace);
          }
        },
      );

      final now = DateTime.now();
      final manufacture = DateTime(now.year, now.month, 1);
      final expiry = DateTime(now.year + 1, now.month, 1);
      final batchId = 'it-batch-$suffix';
      final batchCode = 'IT-BATCH-$suffix';
      final transactionRepository =
          SupabaseInventoryTransactions(client: client);
      await transactionRepository.confirmImportReceipt(
        receipt: ImportReceiptModel(
          id: 'it-import-$suffix',
          code: 'IT-IMP-$suffix',
          supplierId: supplierId,
          supplierName: supplier.name,
          date: now,
          riceId: riceId,
          riceName: rice.name,
          quantity: 120,
          purchasePrice: 10.5,
          totalAmount: 1260,
          batchCode: batchCode,
          manufactureDate: manufacture,
          expiryDate: expiry,
        ),
        batchToCreateOrUpdate: BatchModel(
          id: batchId,
          code: batchCode,
          riceId: riceId,
          riceName: rice.name,
          quantity: 120,
          importDate: now,
          manufactureDate: manufacture,
          expiryDate: expiry,
          status: BatchStatus.available,
          supplierId: supplierId,
          supplierName: supplier.name,
        ),
        performedBy: uid,
      );

      final batches = SupabaseBatchRepository(client: client);
      expect((await batches.getById(batchId))?.quantity, 120);
      final imports = supabaseImportReceipts(client: client);
      expect((await imports.getById('it-import-$suffix'))?.quantity, 120);

      await batches.moveBatch(
        batchId: batchId,
        locationId: locationId,
        locationName: 'Test zone → Test rack → Test shelf',
      );
      await locationCountUpdated.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException(
          'Supabase location count did not refresh after a batch move.',
        ),
      );
      expect(
          (await locationRepository.getById(locationId))?.currentBatchCount, 1);
      await locationSubscription.cancel();

      final exportId = 'it-export-$suffix';
      await transactionRepository.confirmExportReceipt(
        receipt: ExportReceiptModel(
          id: exportId,
          code: 'IT-EXP-$suffix',
          customerId: customerId,
          customerName: 'Integration customer $suffix',
          date: now,
          riceId: riceId,
          riceName: rice.name,
          quantity: 20,
          sellingPrice: 15,
          totalAmount: 300,
          note: '',
          allocations: [
            BatchAllocation(
              batchId: batchId,
              batchCode: batchCode,
              allocatedQuantity: 20,
              batchInitialQuantity: 120,
              batchRemainingQuantity: 100,
              expiryDate: expiry,
            ),
          ],
        ),
        performedBy: uid,
      );
      final exports = supabaseExportReceipts(client: client);
      expect(
          (await exports.getById(exportId))
              ?.allocations
              .single
              .allocatedQuantity,
          20);

      await transactionRepository.confirmDamageReport(
        report: DamageReportModel(
          id: 'it-damage-$suffix',
          code: 'IT-DMG-$suffix',
          batchId: batchId,
          batchCode: batchCode,
          riceId: riceId,
          riceName: rice.name,
          quantity: 5,
          reason: DamageReason.moc,
          createdBy: uid,
          createdAt: now,
        ),
        performedBy: uid,
      );

      await transactionRepository.completeInventoryCheck(
        session: InventoryCheckSession(
          id: 'it-check-$suffix',
          code: 'IT-CHK-$suffix',
          createdAt: now,
          createdBy: uid,
          status: InventoryCheckStatus.completed,
          items: [
            InventoryCheckItem(
              batchId: batchId,
              batchCode: batchCode,
              riceName: rice.name,
              expectedQuantity: 95,
              actualQuantity: 90,
              difference: -5,
              reason: InventoryCheckReason.haoHut,
            ),
          ],
          totalItems: 1,
          totalDifference: -5,
        ),
        performedBy: uid,
      );
      expect((await batches.getById(batchId))?.quantity, 90);
      final checks = supabaseInventoryChecks(client: client);
      expect(
          (await checks.getById('it-check-$suffix'))?.items.single.difference,
          -5);

      await auth.signOut();
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
