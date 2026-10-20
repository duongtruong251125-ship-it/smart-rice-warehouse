import 'dart:convert';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_rice_warehouse/data/firebase/config/firestore_paths.dart';
import 'package:smart_rice_warehouse/data/local/seed_migration_policy.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/batch_mapper.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/inventory_transaction_repository.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/repository_exception.dart';
import 'package:smart_rice_warehouse/logic/models/batch_allocation_model.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/damage_report_model.dart';
import 'package:smart_rice_warehouse/logic/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/inventory_check_model.dart';
import 'package:smart_rice_warehouse/logic/models/rice_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  const batchMapper = BatchMapper();

  group('Real SQLite Database Upgrade Testing (sqflite_common_ffi)', () {
    test(
        'v3 to v4 upgrade preserves user data and does not inject sample batches or receipts',
        () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE app_state (
                state_key TEXT PRIMARY KEY,
                payload TEXT NOT NULL
              )
            ''');

            // 1. Dữ liệu gạo thật của người dùng
            final userRice = [
              {
                'id': 'rice-user-1',
                'code': 'G-USER-01',
                'name': 'Gạo Tự Nhập Của Người Dùng',
                'category': 'Đặc sản',
                'unit': 'kg',
                'purchasePrice': 22000.0,
                'sellingPrice': 28000.0,
                'minimumStock': 100.0,
                'description': 'Gạo thật',
                'imagePath': 'local_photos/rice.jpg',
                'isActive': true,
              }
            ];

            // 2. Lô hàng thật của người dùng
            final userBatches = [
              {
                'id': 'batch-user-1',
                'code': 'LO-USER-2026',
                'riceId': 'rice-user-1',
                'riceName': 'Gạo Tự Nhập Của Người Dùng',
                'quantity': 1500.0,
                'importDate': '2026-10-01T08:00:00.000Z',
                'manufactureDate': '2026-10-01T08:00:00.000Z',
                'expiryDate': '2027-10-01T08:00:00.000Z',
                'status': 'available',
              }
            ];

            // 3. Phiếu nhập thật của người dùng
            final userReceipts = [
              {
                'id': 'imp-user-1',
                'code': 'PN-USER-001',
                'supplierId': 'sup-1',
                'supplierName': 'Nhà Cung Cấp A',
                'date': '2026-10-01T08:00:00.000Z',
                'riceId': 'rice-user-1',
                'riceName': 'Gạo Tự Nhập Của Người Dùng',
                'quantity': 1500.0,
                'purchasePrice': 22000.0,
                'totalAmount': 33000000.0,
                'batchCode': 'LO-USER-2026',
                'manufactureDate': '2026-10-01T08:00:00.000Z',
                'expiryDate': '2027-10-01T08:00:00.000Z',
              }
            ];

            await db.insert('app_state', {
              'state_key': 'rices',
              'payload': jsonEncode(userRice),
            });
            await db.insert('app_state', {
              'state_key': 'batches',
              'payload': jsonEncode(userBatches),
            });
            await db.insert('app_state', {
              'state_key': 'import_receipts',
              'payload': jsonEncode(userReceipts),
            });
            await db.insert('app_state', {
              'state_key': 'local_seed_version',
              'payload': jsonEncode(3),
            });
          },
        ),
      );

      addTearDown(() async => db.close());

      // Thực hiện logic migration v3 -> v4
      const policy = SeedMigrationPolicy();
      final rows = await db.query(
        'app_state',
        where: 'state_key = ?',
        whereArgs: ['rices'],
      );
      final rawList =
          jsonDecode(rows.first['payload'] as String) as List<dynamic>;
      final existingRices = rawList
          .map((m) => RiceModel.fromJson(m as Map<String, dynamic>))
          .toList();

      final sampleRices = <RiceModel>[
        const RiceModel(
          id: 'rice-sample-st25',
          code: 'ST25',
          name: 'Gạo ST25 Mẫu',
          category: 'Đặc sản',
          unit: 'kg',
          purchasePrice: 24000,
          sellingPrice: 32000,
          minimumStock: 200,
          description: 'Gạo ST25 mẫu',
          isActive: true,
          imagePath: 'assets/images/rice/st25.jpg',
        ),
      ];

      final migratedRices = policy.migrateRicesV3ToV4(
        existingRices: existingRices,
        sampleRices: sampleRices,
      );

      await db.insert(
        'app_state',
        {
          'state_key': 'rices',
          'payload': jsonEncode(migratedRices.map((r) => r.toJson()).toList()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await db.insert(
        'app_state',
        {'state_key': 'local_seed_version', 'payload': jsonEncode(4)},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // KIỂM TRA BẢO TOÀN DỮ LIỆU:
      // 1. Số lượng lô hàng vẫn CHÍNH XÁC là 1 lô của người dùng, KHÔNG bị chèn lô mẫu nào
      final batchesRow = await db.query(
        'app_state',
        where: 'state_key = ?',
        whereArgs: ['batches'],
      );
      final batches =
          jsonDecode(batchesRow.first['payload'] as String) as List<dynamic>;
      expect(batches.length, 1);
      expect(batches.first['id'], 'batch-user-1');
      expect(batches.first['code'], 'LO-USER-2026');
      expect(batches.first['quantity'], 1500.0);

      // 2. Số lượng phiếu nhập vẫn CHÍNH XÁC là 1 phiếu của người dùng
      final receiptsRow = await db.query(
        'app_state',
        where: 'state_key = ?',
        whereArgs: ['import_receipts'],
      );
      final receipts =
          jsonDecode(receiptsRow.first['payload'] as String) as List<dynamic>;
      expect(receipts.length, 1);
      expect(receipts.first['id'], 'imp-user-1');
      expect(receipts.first['code'], 'PN-USER-001');

      // 3. Gạo của người dùng không bị xóa, và không bị chèn thêm gạo mẫu
      final ricesRow = await db.query(
        'app_state',
        where: 'state_key = ?',
        whereArgs: ['rices'],
      );
      final rices =
          jsonDecode(ricesRow.first['payload'] as String) as List<dynamic>;
      expect(rices.length, 1);
      expect(rices.first['id'], 'rice-user-1');
      expect(rices.first['imagePath'], 'local_photos/rice.jpg');

      // 4. Version cập nhật thành công lên 4
      final versionRow = await db.query(
        'app_state',
        where: 'state_key = ?',
        whereArgs: ['local_seed_version'],
      );
      expect(jsonDecode(versionRow.first['payload'] as String), 4);
    });

    test('Fresh install with seed_version 0 inserts initial data correctly',
        () async {
      const policy = SeedMigrationPolicy();
      expect(
        policy.shouldSkipInitialSeedOverwrite(
          installedVersion: 0,
          hasExistingData: false,
        ),
        isFalse,
      );
      expect(
        policy.shouldSkipInitialSeedOverwrite(
          installedVersion: 0,
          hasExistingData: true,
        ),
        isTrue,
      );
    });
  });

  group('Multi-batch Export Transactions (Read-Before-Write & Atomicity)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late InventoryTransactionRepository repository;
    final now = DateTime(2026, 10, 20);

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repository = InventoryTransactionRepository(firestore: fakeFirestore);
    });

    test('Multi-batch export reads all batches first, updates stock atomically',
        () async {
      // Chuẩn bị 2 lô trong Firestore
      final batch1 = BatchModel(
        id: 'b-1',
        code: 'LO-01',
        riceId: 'r-1',
        riceName: 'Gạo ST25',
        quantity: 500.0,
        importDate: now,
        manufactureDate: now,
        expiryDate: now.add(const Duration(days: 90)),
        status: BatchStatus.available,
      );
      final batch2 = BatchModel(
        id: 'b-2',
        code: 'LO-02',
        riceId: 'r-1',
        riceName: 'Gạo ST25',
        quantity: 400.0,
        importDate: now,
        manufactureDate: now,
        expiryDate: now.add(const Duration(days: 90)),
        status: BatchStatus.available,
      );

      await fakeFirestore
          .collection(FirestorePaths.batches)
          .doc('b-1')
          .set(batchMapper.toFirestore(batch1, null));
      await fakeFirestore
          .collection(FirestorePaths.batches)
          .doc('b-2')
          .set(batchMapper.toFirestore(batch2, null));

      // Tạo phiếu xuất gồm 2 allocations (lô 1: 200kg, lô 2: 300kg)
      final exportReceipt = ExportReceiptModel(
        id: 'exp-multi-1',
        code: 'PX-MULTI-01',
        customerId: 'cust-1',
        customerName: 'Đại lý Miền Nam',
        date: now,
        riceId: 'r-1',
        riceName: 'Gạo ST25',
        quantity: 500,
        sellingPrice: 26000,
        totalAmount: 13000000,
        note: 'Xuất 2 lô',
        allocations: [
          BatchAllocation(
            batchId: 'b-1',
            batchCode: 'LO-01',
            allocatedQuantity: 200,
            batchInitialQuantity: 500,
            batchRemainingQuantity: 300,
            expiryDate: now.add(const Duration(days: 90)),
          ),
          BatchAllocation(
            batchId: 'b-2',
            batchCode: 'LO-02',
            allocatedQuantity: 300,
            batchInitialQuantity: 400,
            batchRemainingQuantity: 100,
            expiryDate: now.add(const Duration(days: 90)),
          ),
        ],
      );

      // Thực hiện xác nhận xuất kho
      await repository.confirmExportReceipt(
        receipt: exportReceipt,
        performedBy: 'Thủ kho Test',
      );

      // Kiểm tra cả 2 lô đều bị trừ đúng số lượng trong 1 giao dịch
      final b1Doc = await fakeFirestore
          .collection(FirestorePaths.batches)
          .doc('b-1')
          .get();
      final b2Doc = await fakeFirestore
          .collection(FirestorePaths.batches)
          .doc('b-2')
          .get();

      expect(b1Doc.data()!['remainingQuantity'], 300.0); // 500 - 200
      expect(b2Doc.data()!['remainingQuantity'], 100.0); // 400 - 300

      // Kiểm tra 2 bản ghi lịch sử xuất kho stock_movements
      final movements = await fakeFirestore
          .collection(FirestorePaths.stockMovements)
          .where('referenceId', isEqualTo: exportReceipt.id)
          .get();
      expect(movements.docs.length, 2);
    });

    test(
        'Multi-batch export fails atomically if any batch has insufficient stock (no partial deduct)',
        () async {
      // Lô 1 có 500kg, Lô 2 chỉ có 100kg
      final batch1 = BatchModel(
        id: 'b-1',
        code: 'LO-01',
        riceId: 'r-1',
        riceName: 'Gạo ST25',
        quantity: 500.0,
        importDate: now,
        manufactureDate: now,
        expiryDate: now.add(const Duration(days: 90)),
        status: BatchStatus.available,
      );
      final batch2 = BatchModel(
        id: 'b-2',
        code: 'LO-02',
        riceId: 'r-1',
        riceName: 'Gạo ST25',
        quantity: 100.0,
        importDate: now,
        manufactureDate: now,
        expiryDate: now.add(const Duration(days: 90)),
        status: BatchStatus.available,
      );

      await fakeFirestore
          .collection(FirestorePaths.batches)
          .doc('b-1')
          .set(batchMapper.toFirestore(batch1, null));
      await fakeFirestore
          .collection(FirestorePaths.batches)
          .doc('b-2')
          .set(batchMapper.toFirestore(batch2, null));

      // Phiếu xuất muốn lấy 200kg từ lô 1, nhưng đòi 300kg từ lô 2 (thiếu 200kg)
      final exportReceipt = ExportReceiptModel(
        id: 'exp-multi-fail',
        code: 'PX-FAIL-01',
        customerId: 'cust-1',
        customerName: 'Đại lý Miền Nam',
        date: now,
        riceId: 'r-1',
        riceName: 'Gạo ST25',
        quantity: 500,
        sellingPrice: 26000,
        totalAmount: 13000000,
        note: 'Xuất lỗi',
        allocations: [
          BatchAllocation(
            batchId: 'b-1',
            batchCode: 'LO-01',
            allocatedQuantity: 200,
            batchInitialQuantity: 500,
            batchRemainingQuantity: 300,
            expiryDate: now.add(const Duration(days: 90)),
          ),
          BatchAllocation(
            batchId: 'b-2',
            batchCode: 'LO-02',
            allocatedQuantity: 300, // Đòi 300kg nhưng lô 2 chỉ có 100kg
            batchInitialQuantity: 100,
            batchRemainingQuantity: -200,
            expiryDate: now.add(const Duration(days: 90)),
          ),
        ],
      );

      // Giao dịch phải ném ngoại lệ RepositoryException với mã insufficient_stock
      expect(
        () => repository.confirmExportReceipt(
          receipt: exportReceipt,
          performedBy: 'Thủ kho Test',
        ),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.code,
            'code',
            'insufficient_stock',
          ),
        ),
      );

      // BẢO ĐẢM TÍNH NGUYÊN TỬ: Lô 1 tuyệt đối KHÔNG bị trừ một phần nào!
      final b1Doc = await fakeFirestore
          .collection(FirestorePaths.batches)
          .doc('b-1')
          .get();
      final b2Doc = await fakeFirestore
          .collection(FirestorePaths.batches)
          .doc('b-2')
          .get();
      expect(b1Doc.data()!['remainingQuantity'], 500.0,
          reason:
              'Batch 1 must not be partially deducted when transaction fails');
      expect(b2Doc.data()!['remainingQuantity'], 100.0);

      // Không có stock_movement nào được tạo
      final movements = await fakeFirestore
          .collection(FirestorePaths.stockMovements)
          .where('referenceId', isEqualTo: exportReceipt.id)
          .get();
      expect(movements.docs, isEmpty);
    });
  });

  group('Multi-batch Inventory Check & Concurrency Conflicts', () {
    late FakeFirebaseFirestore fakeFirestore;
    late InventoryTransactionRepository repository;
    final now = DateTime(2026, 10, 20);

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repository = InventoryTransactionRepository(firestore: fakeFirestore);
    });

    test(
        'Inventory check detects stock change during count and rejects cleanly',
        () async {
      // Lô hàng ban đầu có 500kg
      final batch = BatchModel(
        id: 'b-check-1',
        code: 'LO-CHK-1',
        riceId: 'r-1',
        riceName: 'Gạo ST25',
        quantity: 500.0,
        importDate: now,
        manufactureDate: now,
        expiryDate: now.add(const Duration(days: 90)),
        status: BatchStatus.available,
      );

      await fakeFirestore
          .collection(FirestorePaths.batches)
          .doc('b-check-1')
          .set(batchMapper.toFirestore(batch, null));

      // Người dùng tạo phiên kiểm kê ghi nhận tồn lúc bắt đầu là 500kg, thực tế đếm 480kg
      final session = InventoryCheckSession(
        id: 'session-conflict',
        code: 'KK-CONF-01',
        createdAt: now,
        createdBy: 'Admin',
        status: InventoryCheckStatus.inProgress,
        items: [
          const InventoryCheckItem(
            batchId: 'b-check-1',
            batchCode: 'LO-CHK-1',
            riceName: 'Gạo ST25',
            expectedQuantity: 500.0, // Tồn lúc bắt đầu kiểm kê
            actualQuantity: 480.0,
            difference: -20.0,
            reason: InventoryCheckReason.haoHut,
          ),
        ],
      );

      // GIẢ LẬP XUNG ĐỘT 2 THIẾT BỊ: Trong khi thiết bị 1 đang đếm hàng,
      // Thiết bị 2 đã xuất 100kg khiến tồn kho thực tế đổi thành 400kg
      await fakeFirestore
          .collection(FirestorePaths.batches)
          .doc('b-check-1')
          .update({'quantity': 400.0, 'remainingQuantity': 400.0});

      // Thiết bị 1 hoàn tất kiểm kê -> planner phát hiện expectedQuantity (500) != currentStock (400)
      expect(
        () => repository.completeInventoryCheck(
          session: session,
          performedBy: 'Thủ kho 1',
        ),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.code,
            'code',
            'stock_changed',
          ),
        ),
      );

      // Tồn kho không bị ghi đè sai lệch thành 480kg, vẫn giữ nguyên 400kg của thiết bị 2
      final batchDoc = await fakeFirestore
          .collection(FirestorePaths.batches)
          .doc('b-check-1')
          .get();
      expect(batchDoc.data()!['remainingQuantity'], 400.0);
    });
  });

  group('Supplement Import (Nhập bổ sung vào lô hiện có)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late InventoryTransactionRepository repository;
    final now = DateTime(2026, 10, 20);

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repository = InventoryTransactionRepository(firestore: fakeFirestore);
    });

    test(
        'Supplement import updates existing batch quantity without creating duplicate batch document',
        () async {
      // 1. Tạo lô hiện có trong kho: LO-SUPP-01 có 1000kg
      final existingBatch = BatchModel(
        id: 'batch-existing-1',
        code: 'LO-SUPP-01',
        riceId: 'rice-1',
        riceName: 'Gạo Nàng Hoa',
        quantity: 1000,
        importDate: now.subtract(const Duration(days: 5)),
        manufactureDate: now.subtract(const Duration(days: 5)),
        expiryDate: now.add(const Duration(days: 180)),
        status: BatchStatus.available,
      );

      await fakeFirestore
          .collection(FirestorePaths.batches)
          .doc(existingBatch.id)
          .set(batchMapper.toFirestore(existingBatch, null));

      // Đăng ký batch code
      await fakeFirestore
          .collection(FirestorePaths.batchCodes)
          .doc('LO-SUPP-01')
          .set({'batchCode': 'LO-SUPP-01', 'batchId': existingBatch.id});

      // 2. Thực hiện nhập bổ sung thêm 500kg vào chính lô LO-SUPP-01 này (cùng ngày sản xuất, hạn dùng)
      final supplementReceipt = ImportReceiptModel(
        id: 'imp-supp-01',
        code: 'PN-SUPP-01',
        supplierId: 'sup-1',
        supplierName: 'Nhà máy gạo',
        date: now,
        riceId: 'rice-1',
        riceName: 'Gạo Nàng Hoa',
        quantity: 500,
        purchasePrice: 18000,
        totalAmount: 9000000,
        batchCode: 'LO-SUPP-01',
        manufactureDate: existingBatch.manufactureDate,
        expiryDate: existingBatch.expiryDate,
      );

      // Gửi batchToCreateOrUpdate: cùng mã lô và ID
      final updatedBatchModel = existingBatch.copyWith(
        quantity: 500, // Lượng nhập của phiếu
      );

      await repository.confirmImportReceipt(
        receipt: supplementReceipt,
        batchToCreateOrUpdate: updatedBatchModel,
        performedBy: 'Thủ kho A',
      );

      // 3. Xác minh: Số lượng lô hàng trong Firestore VẪN CHỈ LÀ 1 (không sinh tài liệu trùng mã)
      final allBatches =
          await fakeFirestore.collection(FirestorePaths.batches).get();
      expect(allBatches.docs.length, 1);
      expect(allBatches.docs.first.id, 'batch-existing-1');
      expect(allBatches.docs.first.data()['code'], 'LO-SUPP-01');
      expect(allBatches.docs.first.data()['remainingQuantity'],
          1500.0); // 1000 + 500

      // Kiểm tra stock movement ghi nhận lượng nhập là +500
      final movementDoc = await fakeFirestore
          .collection(FirestorePaths.stockMovements)
          .doc('mov_imp_imp-supp-01')
          .get();
      expect(movementDoc.exists, isTrue);
      expect(movementDoc.data()!['quantityDelta'], 500.0);
    });
  });

  group('Duplicate Confirmation Prevention (Chống xác nhận lặp)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late InventoryTransactionRepository repository;
    final now = DateTime(2026, 10, 20);

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repository = InventoryTransactionRepository(firestore: fakeFirestore);
    });

    test('Re-confirming confirmed import receipt throws already_confirmed',
        () async {
      final receipt = ImportReceiptModel(
        id: 'imp-dup-1',
        code: 'PN-DUP-01',
        supplierId: 's-1',
        supplierName: 'NCC 1',
        date: now,
        riceId: 'r-1',
        riceName: 'Gạo',
        quantity: 100,
        purchasePrice: 15000,
        totalAmount: 1500000,
        batchCode: 'LO-DUMMY',
        manufactureDate: now,
        expiryDate: now,
      );

      final dummyBatch = BatchModel(
        id: 'b-dummy',
        code: 'LO-DUMMY',
        riceId: 'r-1',
        riceName: 'Gạo',
        quantity: 100,
        importDate: now,
        manufactureDate: now,
        expiryDate: now,
        status: BatchStatus.available,
      );

      // Lần xác nhận 1
      await repository.confirmImportReceipt(
        receipt: receipt,
        batchToCreateOrUpdate: dummyBatch,
        performedBy: 'User',
      );

      // Lần xác nhận 2: phải báo lỗi already_confirmed
      expect(
        () => repository.confirmImportReceipt(
          receipt: receipt,
          batchToCreateOrUpdate: dummyBatch,
          performedBy: 'User',
        ),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.code,
            'code',
            'already_confirmed',
          ),
        ),
      );
    });

    test('Re-confirming confirmed export receipt throws already_confirmed',
        () async {
      final batch = BatchModel(
        id: 'b-dup',
        code: 'LO-DUP-01',
        riceId: 'r-1',
        riceName: 'Gạo',
        quantity: 500,
        importDate: now,
        manufactureDate: now,
        expiryDate: now.add(const Duration(days: 30)),
        status: BatchStatus.available,
      );
      await fakeFirestore
          .collection(FirestorePaths.batches)
          .doc(batch.id)
          .set(batchMapper.toFirestore(batch, null));

      final receipt = ExportReceiptModel(
        id: 'exp-dup-1',
        code: 'PX-DUP-01',
        customerId: 'c-1',
        customerName: 'Khách',
        date: now,
        riceId: 'r-1',
        riceName: 'Gạo',
        quantity: 100,
        sellingPrice: 20000,
        totalAmount: 2000000,
        note: '',
        allocations: [
          BatchAllocation(
            batchId: batch.id,
            batchCode: batch.code,
            allocatedQuantity: 100,
            batchInitialQuantity: 500,
            batchRemainingQuantity: 400,
            expiryDate: batch.expiryDate,
          ),
        ],
      );

      // Lần 1
      await repository.confirmExportReceipt(
        receipt: receipt,
        performedBy: 'User',
      );

      // Lần 2: phải báo lỗi already_confirmed
      expect(
        () => repository.confirmExportReceipt(
          receipt: receipt,
          performedBy: 'User',
        ),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.code,
            'code',
            'already_confirmed',
          ),
        ),
      );
    });

    test('Re-confirming confirmed damage report throws already_confirmed',
        () async {
      final batch = BatchModel(
        id: 'b-dmg-dup',
        code: 'LO-DMG-01',
        riceId: 'r-1',
        riceName: 'Gạo',
        quantity: 500,
        importDate: now,
        manufactureDate: now,
        expiryDate: now.add(const Duration(days: 30)),
        status: BatchStatus.available,
      );
      await fakeFirestore
          .collection(FirestorePaths.batches)
          .doc(batch.id)
          .set(batchMapper.toFirestore(batch, null));

      final report = DamageReportModel(
        id: 'dmg-dup-1',
        code: 'BH-DUP-01',
        batchId: batch.id,
        batchCode: batch.code,
        riceId: batch.riceId,
        riceName: batch.riceName,
        quantity: 10,
        reason: DamageReason.moc,
        createdAt: now,
        createdBy: 'Admin',
        status: DamageReportStatus.confirmed,
      );

      // Lần 1
      await repository.confirmDamageReport(
        report: report,
        performedBy: 'User',
      );

      // Lần 2: phải báo lỗi already_confirmed
      expect(
        () => repository.confirmDamageReport(
          report: report,
          performedBy: 'User',
        ),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.code,
            'code',
            'already_confirmed',
          ),
        ),
      );
    });
  });

  group('Two-device Batch Code Conflict (Xung đột mã lô hai thiết bị)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late InventoryTransactionRepository repository;
    final now = DateTime(2026, 10, 20);

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repository = InventoryTransactionRepository(firestore: fakeFirestore);
    });

    test(
        'Two devices attempting to create different batches with same batchCode fails on second device',
        () async {
      // Thiết bị 1 nhập lô 'LO-RACE-01' với NCC 1
      final receipt1 = ImportReceiptModel(
        id: 'imp-race-1',
        code: 'PN-RACE-01',
        supplierId: 'sup-1',
        supplierName: 'NCC 1',
        date: now,
        riceId: 'rice-1',
        riceName: 'Gạo ST25',
        quantity: 1000,
        purchasePrice: 20000,
        totalAmount: 20000000,
        batchCode: 'LO-RACE-01',
        manufactureDate: now,
        expiryDate: now.add(const Duration(days: 180)),
      );
      final batch1 = BatchModel(
        id: 'batch-device-1',
        code: 'LO-RACE-01',
        riceId: 'rice-1',
        riceName: 'Gạo ST25',
        quantity: 1000,
        importDate: now,
        manufactureDate: now,
        expiryDate: now.add(const Duration(days: 180)),
        status: BatchStatus.available,
        supplierId: 'sup-1',
        supplierName: 'NCC 1',
      );

      await repository.confirmImportReceipt(
        receipt: receipt1,
        batchToCreateOrUpdate: batch1,
        performedBy: 'Thiết bị 1',
      );

      // Thiết bị 2 cố tình tạo lô 'LO-RACE-01' nhưng khác nhà cung cấp (NCC 2)
      final receipt2 = ImportReceiptModel(
        id: 'imp-race-2',
        code: 'PN-RACE-02',
        supplierId: 'sup-2',
        supplierName: 'NCC 2',
        date: now,
        riceId: 'rice-1',
        riceName: 'Gạo ST25',
        quantity: 800,
        purchasePrice: 21000,
        totalAmount: 16800000,
        batchCode: 'LO-RACE-01', // Cùng mã lô
        manufactureDate: now,
        expiryDate: now.add(const Duration(days: 180)),
      );
      final batch2 = BatchModel(
        id: 'batch-device-2',
        code: 'LO-RACE-01',
        riceId: 'rice-1',
        riceName: 'Gạo ST25',
        quantity: 800,
        importDate: now,
        manufactureDate: now,
        expiryDate: now.add(const Duration(days: 180)),
        status: BatchStatus.available,
        supplierId: 'sup-2',
        supplierName: 'NCC 2',
      );

      // Phải bị từ chối với lỗi batch_code_conflict
      expect(
        () => repository.confirmImportReceipt(
          receipt: receipt2,
          batchToCreateOrUpdate: batch2,
          performedBy: 'Thiết bị 2',
        ),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.code,
            'code',
            'batch_code_conflict',
          ),
        ),
      );

      // Kiểm tra trong database chỉ có đúng 1 lô của thiết bị 1
      final batches =
          await fakeFirestore.collection(FirestorePaths.batches).get();
      expect(batches.docs.length, 1);
      expect(batches.docs.first.id, 'batch-device-1');
    });
  });
}
