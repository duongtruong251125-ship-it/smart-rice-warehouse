import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_rice_warehouse/logic/contracts/inventory_transactions.dart';
import 'package:smart_rice_warehouse/data/firebase/config/firestore_paths.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/damage_report_model.dart';
import 'package:smart_rice_warehouse/logic/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/inventory_check_model.dart';
import 'package:smart_rice_warehouse/logic/models/stock_movement_model.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/repository_exception.dart';
import 'package:smart_rice_warehouse/logic/services/stock_transaction_planner.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/batch_mapper.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/damage_report_mapper.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/export_receipt_mapper.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/import_receipt_mapper.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/inventory_check_mapper.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/stock_movement_mapper.dart';

/// Applies warehouse stock transactions to Firestore.
///
/// Legacy direct-client adapter retained for existing planner/atomicity tests.
/// Production bootstrap uses CallableInventoryTransactions: security rules
/// intentionally reject the client writes made by this legacy adapter.
///
/// Every method follows the same protocol inside `runTransaction`:
/// 1. read every document the operation depends on,
/// 2. validate the complete state with [StockTransactionPlanner],
/// 3. only then write the whole plan.
///
/// Firestore retries the handler with fresh data when another device commits
/// a conflicting change, so validation always runs on current stock. Receipts
/// and stock movements use deterministic IDs and are create-only in Security
/// Rules, so a repeated confirmation can never apply stock twice.
class InventoryTransactionRepository implements InventoryTransactions {
  InventoryTransactionRepository({
    required FirebaseFirestore firestore,
    DateTime Function()? clock,
  })  : _firestore = firestore,
        _clock = clock ?? DateTime.now;

  final FirebaseFirestore _firestore;
  final DateTime Function() _clock;

  static const _planner = StockTransactionPlanner();
  static const _batchMapper = BatchMapper();
  static const _importMapper = ImportReceiptMapper();
  static const _exportMapper = ExportReceiptMapper();
  static const _damageMapper = DamageReportMapper();
  static const _checkMapper = InventoryCheckMapper();
  static const _movementMapper = StockMovementMapper();

  CollectionReference<Map<String, dynamic>> get _batches =>
      _firestore.collection(FirestorePaths.batches);

  /// Xác nhận phiếu nhập kho nguyên tử.
  ///
  /// Nhập bổ sung cập nhật đúng lô đang có cùng mã (tìm qua tài liệu giữ chỗ
  /// `batch_codes` và truy vấn mã cho dữ liệu cũ), không tạo lô trùng mã.
  @override
  Future<void> confirmImportReceipt({
    required ImportReceiptModel receipt,
    required BatchModel batchToCreateOrUpdate,
    required String performedBy,
  }) {
    return _guard('nhập kho', () async {
      final codeKey =
          StockTransactionPlanner.batchCodeKey(batchToCreateOrUpdate.code);
      // Legacy batches created before code reservations existed are found by
      // an exact-code query. The transaction re-reads each candidate.
      final legacy = await _batches
          .where('code', isEqualTo: batchToCreateOrUpdate.code.trim())
          .limit(10)
          .get();
      final candidateIds = <String>{
        batchToCreateOrUpdate.id,
        ...legacy.docs.map((doc) => doc.id),
      };

      await _firestore.runTransaction((transaction) async {
        // ---- Reads -------------------------------------------------------
        final receiptRef = _firestore
            .collection(FirestorePaths.importReceipts)
            .doc(receipt.id);
        final codeRef =
            _firestore.collection(FirestorePaths.batchCodes).doc(codeKey);
        final receiptSnap = await transaction.get(receiptRef);
        final codeSnap = await transaction.get(codeRef);
        final reservedId = codeSnap.data()?['batchId'] as String?;
        final ids = {...candidateIds, if (reservedId != null) reservedId};
        final existing = <BatchModel>[];
        for (final id in ids) {
          final snap = await transaction.get(_batches.doc(id));
          if (snap.exists) {
            existing.add(_batchMapper.fromMap(snap.id, snap.data()!));
          }
        }

        // ---- Validate & plan ---------------------------------------------
        final plan = _planner.planImport(
          receipt: receipt,
          requestedBatch: batchToCreateOrUpdate,
          receiptExists: receiptSnap.exists,
          existingBatchesWithCode: existing,
          performedBy: performedBy,
          now: _clock(),
        );

        // ---- Writes ------------------------------------------------------
        final target = plan.batchWrites.single;
        _writeBatch(transaction, target);
        if (reservedId != target.batch.id) {
          transaction.set(codeRef, {
            'batchId': target.batch.id,
            'code': target.batch.code.trim(),
          });
        }
        transaction.set(receiptRef, _importMapper.toFirestore(receipt, null));
        _writeMovements(transaction, plan.movements);
      });
    });
  }

  /// Xác nhận phiếu xuất kho nhiều lô: đọc mọi lô trước, kiểm tra đủ tồn rồi
  /// mới trừ tồn; thiếu một lô thì không lô nào bị trừ.
  @override
  Future<void> confirmExportReceipt({
    required ExportReceiptModel receipt,
    required String performedBy,
  }) {
    return _guard('xuất kho', () async {
      final batchIds = _planner.requestedQuantities(receipt).keys.toList();
      await _firestore.runTransaction((transaction) async {
        final receiptRef = _firestore
            .collection(FirestorePaths.exportReceipts)
            .doc(receipt.id);
        final receiptSnap = await transaction.get(receiptRef);
        final batches = await _readBatches(transaction, batchIds);

        final plan = _planner.planExport(
          receipt: receipt,
          receiptExists: receiptSnap.exists,
          batchesById: batches,
          performedBy: performedBy,
          now: _clock(),
        );

        for (final write in plan.batchWrites) {
          _writeBatch(transaction, write);
        }
        _writeMovements(transaction, plan.movements);
        transaction.set(receiptRef, _exportMapper.toFirestore(receipt, null));
      });
    });
  }

  /// Ghi nhận báo hỏng gạo và trừ tồn kho.
  @override
  Future<void> confirmDamageReport({
    required DamageReportModel report,
    required String performedBy,
  }) {
    return _guard('báo hỏng gạo', () async {
      await _firestore.runTransaction((transaction) async {
        final reportRef =
            _firestore.collection(FirestorePaths.damageReports).doc(report.id);
        final reportSnap = await transaction.get(reportRef);
        final batchSnap = await transaction.get(_batches.doc(report.batchId));

        if (reportSnap.exists) {
          throw const RepositoryException(
            'Biên bản báo hỏng này đã tồn tại.',
            code: StockTransactionError.alreadyConfirmed,
          );
        }
        if (!report.quantity.isFinite || report.quantity <= 0) {
          throw const RepositoryException(
            'Số lượng báo hỏng phải lớn hơn 0.',
            code: StockTransactionError.invalidQuantity,
          );
        }
        if (!batchSnap.exists) {
          throw RepositoryException(
            'Lô hàng ${report.batchCode} không tồn tại.',
            code: StockTransactionError.batchNotFound,
          );
        }
        final batch = _batchMapper.fromMap(batchSnap.id, batchSnap.data()!);
        if (batch.quantity < report.quantity - 0.0001) {
          throw const RepositoryException(
            'Số lượng báo hỏng vượt quá số lượng tồn của lô hàng.',
            code: StockTransactionError.insufficientStock,
          );
        }

        final quantityBefore = batch.quantity;
        final quantityAfter =
            (quantityBefore - report.quantity).clamp(0.0, double.infinity);
        _writeBatch(
          transaction,
          PlannedBatchWrite(
            batch: batch.copyWith(quantity: quantityAfter),
            isNew: false,
            quantityBefore: quantityBefore,
          ),
        );
        transaction.set(reportRef, _damageMapper.toFirestore(report, null));
        _writeMovements(transaction, [
          StockMovementModel(
            id: 'mov_dmg_${report.id}',
            type: 'damage',
            batchId: report.batchId,
            riceId: report.riceId,
            quantityDelta: -report.quantity,
            quantityBefore: quantityBefore,
            quantityAfter: quantityAfter,
            referenceType: 'damage_report',
            referenceId: report.id,
            performedBy: performedBy,
            createdAt: _clock(),
            note: 'Hao hụt/hư hỏng: ${report.reason.label}',
          ),
        ]);
      });
    });
  }

  /// Hoàn tất phiên kiểm kê nhiều lô: đọc phiên và mọi lô cần điều chỉnh,
  /// từ chối nếu tồn đã đổi sau khi đếm hoặc phiên đã hoàn tất.
  @override
  Future<void> completeInventoryCheck({
    required InventoryCheckSession session,
    required String performedBy,
  }) {
    return _guard('kiểm kê kho', () async {
      final batchIds = _planner.adjustedBatchIds(session).toList();
      await _firestore.runTransaction((transaction) async {
        final checkRef = _firestore
            .collection(FirestorePaths.inventoryChecks)
            .doc(session.id);
        final checkSnap = await transaction.get(checkRef);
        final batches = await _readBatches(transaction, batchIds);
        final storedStatus = checkSnap.exists
            ? _checkMapper.fromMap(checkSnap.id, checkSnap.data()!).status
            : null;

        final plan = _planner.planInventoryCheck(
          session: session,
          storedStatus: storedStatus,
          batchesById: batches,
          performedBy: performedBy,
          now: _clock(),
        );

        for (final write in plan.batchWrites) {
          _writeBatch(transaction, write);
        }
        _writeMovements(transaction, plan.movements);
        transaction.set(checkRef, _checkMapper.toFirestore(session, null));
      });
    });
  }

  Future<Map<String, BatchModel?>> _readBatches(
    Transaction transaction,
    Iterable<String> ids,
  ) async {
    final result = <String, BatchModel?>{};
    for (final id in ids) {
      final snap = await transaction.get(_batches.doc(id));
      result[id] =
          snap.exists ? _batchMapper.fromMap(snap.id, snap.data()!) : null;
    }
    return result;
  }

  void _writeBatch(Transaction transaction, PlannedBatchWrite write) {
    final ref = _batches.doc(write.batch.id);
    final data = _batchMapper.toFirestore(write.batch, null)
      ..['updatedAt'] = FieldValue.serverTimestamp();
    if (write.isNew) {
      data['createdAt'] = FieldValue.serverTimestamp();
      transaction.set(ref, data);
    } else {
      transaction.update(ref, data);
    }
  }

  void _writeMovements(
    Transaction transaction,
    List<StockMovementModel> movements,
  ) {
    for (final movement in movements) {
      transaction.set(
        _firestore.collection(FirestorePaths.stockMovements).doc(movement.id),
        _movementMapper.toFirestore(movement, null),
      );
    }
  }

  Future<void> _guard(String action, Future<void> Function() body) async {
    try {
      await body();
    } on RepositoryException {
      rethrow;
    } on FirebaseException catch (error) {
      throw RepositoryException(
        _firebaseMessage(action, error),
        code: error.code,
        cause: error,
      );
    }
  }

  static String _firebaseMessage(String action, FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Tài khoản không có quyền thực hiện $action.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Mất kết nối máy chủ khi $action. Chưa có thay đổi nào được '
            'ghi; vui lòng thử lại khi có mạng.';
      case 'aborted':
        return 'Dữ liệu đang được thiết bị khác cập nhật. Vui lòng thử lại.';
      default:
        return error.message ?? 'Lỗi giao dịch $action.';
    }
  }
}
