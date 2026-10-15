import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_rice_warehouse/core/firebase/firestore_paths.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/models/damage_report_model.dart';
import 'package:smart_rice_warehouse/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/models/inventory_check_model.dart';
import 'package:smart_rice_warehouse/models/stock_movement_model.dart';
import 'package:smart_rice_warehouse/repositories/contracts/repository_exception.dart';
import 'package:smart_rice_warehouse/repositories/firestore/batch_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/damage_report_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/export_receipt_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/import_receipt_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/inventory_check_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/stock_movement_mapper.dart';

class InventoryTransactionRepository {
  InventoryTransactionRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  static const _batchMapper = BatchMapper();
  static const _importMapper = ImportReceiptMapper();
  static const _exportMapper = ExportReceiptMapper();
  static const _damageMapper = DamageReportMapper();
  static const _checkMapper = InventoryCheckMapper();
  static const _movementMapper = StockMovementMapper();

  /// Xác nhận phiếu nhập kho nguyên tử
  Future<void> confirmImportReceipt({
    required ImportReceiptModel receipt,
    required BatchModel batchToCreateOrUpdate,
    required String performedBy,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final receiptRef = _firestore
            .collection(FirestorePaths.importReceipts)
            .doc(receipt.id);
        final receiptSnap = await transaction.get(receiptRef);
        if (receiptSnap.exists &&
            receiptSnap.data()?['status'] == 'confirmed') {
          throw const RepositoryException(
            'Phiếu nhập kho này đã được xác nhận trước đó.',
            code: 'already_confirmed',
          );
        }

        final batchRef = _firestore
            .collection(FirestorePaths.batches)
            .doc(batchToCreateOrUpdate.id);
        final batchSnap = await transaction.get(batchRef);

        double quantityBefore = 0.0;
        double quantityAfter = batchToCreateOrUpdate.quantity;

        if (batchSnap.exists) {
          final existingBatch = _batchMapper.fromMap(
            batchSnap.id,
            batchSnap.data() ?? const {},
          );
          quantityBefore = existingBatch.quantity;
          quantityAfter = quantityBefore + receipt.quantity;

          transaction.update(
            batchRef,
            _batchMapper.toFirestore(
              existingBatch.copyWith(quantity: quantityAfter),
              null,
            ),
          );
        } else {
          transaction.set(
            batchRef,
            _batchMapper.toFirestore(batchToCreateOrUpdate, null),
          );
        }

        // Lưu phiếu nhập
        transaction.set(
          receiptRef,
          _importMapper.toFirestore(receipt, null),
        );

        // Tạo stock movement
        final movementId =
            'mov_imp_${receipt.id}_${DateTime.now().millisecondsSinceEpoch}';
        final movementRef = _firestore
            .collection(FirestorePaths.stockMovements)
            .doc(movementId);
        final movement = StockMovementModel(
          id: movementId,
          type: 'import',
          batchId: batchToCreateOrUpdate.id,
          riceId: receipt.riceId,
          quantityDelta: receipt.quantity,
          quantityBefore: quantityBefore,
          quantityAfter: quantityAfter,
          referenceType: 'import_receipt',
          referenceId: receipt.id,
          performedBy: performedBy,
          createdAt: DateTime.now(),
          note: 'Nhập kho theo phiếu ${receipt.code}',
        );
        transaction.set(movementRef, _movementMapper.toFirestore(movement, null));
      });
    } on FirebaseException catch (e) {
      throw RepositoryException(
        e.message ?? 'Lỗi giao dịch nhập kho',
        code: e.code,
      );
    }
  }

  /// Xác nhận phiếu xuất kho an toàn với FEFO
  Future<void> confirmExportReceipt({
    required ExportReceiptModel receipt,
    required String performedBy,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final receiptRef = _firestore
            .collection(FirestorePaths.exportReceipts)
            .doc(receipt.id);
        final receiptSnap = await transaction.get(receiptRef);
        if (receiptSnap.exists &&
            receiptSnap.data()?['status'] == 'confirmed') {
          throw const RepositoryException(
            'Phiếu xuất kho này đã được xác nhận trước đó.',
            code: 'already_confirmed',
          );
        }

        // Đọc và kiểm tra tất cả các batch được phân bổ
        for (final allocation in receipt.allocations) {
          final batchRef = _firestore
              .collection(FirestorePaths.batches)
              .doc(allocation.batchId);
          final batchSnap = await transaction.get(batchRef);

          if (!batchSnap.exists) {
            throw RepositoryException(
              'Lô hàng ${allocation.batchCode} không tồn tại trên hệ thống.',
              code: 'batch_not_found',
            );
          }

          final batch = _batchMapper.fromMap(
            batchSnap.id,
            batchSnap.data() ?? const {},
          );

          if (batch.quantity < allocation.allocatedQuantity - 0.0001) {
            throw RepositoryException(
              'Lô ${batch.code} không đủ tồn kho (còn ${batch.quantity}kg, cần xuất ${allocation.allocatedQuantity}kg).',
              code: 'insufficient_stock',
            );
          }

          final quantityBefore = batch.quantity;
          final quantityAfter = (quantityBefore - allocation.allocatedQuantity).clamp(0.0, double.infinity);

          final updatedStatus = quantityAfter <= 0.0001
              ? BatchStatus.qualityHold
              : (quantityAfter <= 100 ? BatchStatus.lowStock : BatchStatus.available);

          transaction.update(
            batchRef,
            _batchMapper.toFirestore(
              batch.copyWith(
                quantity: quantityAfter,
                status: updatedStatus,
              ),
              null,
            ),
          );

          // Tạo stock movement cho từng lô được xuất
          final movementId =
              'mov_exp_${receipt.id}_${batch.id}_${DateTime.now().millisecondsSinceEpoch}';
          final movementRef = _firestore
              .collection(FirestorePaths.stockMovements)
              .doc(movementId);
          final movement = StockMovementModel(
            id: movementId,
            type: 'export',
            batchId: batch.id,
            riceId: receipt.riceId,
            quantityDelta: -allocation.allocatedQuantity,
            quantityBefore: quantityBefore,
            quantityAfter: quantityAfter,
            referenceType: 'export_receipt',
            referenceId: receipt.id,
            performedBy: performedBy,
            createdAt: DateTime.now(),
            note: 'Xuất kho cho khách ${receipt.customerName} theo phiếu ${receipt.code}',
          );
          transaction.set(movementRef, _movementMapper.toFirestore(movement, null));
        }

        // Lưu phiếu xuất
        transaction.set(receiptRef, _exportMapper.toFirestore(receipt, null));
      });
    } on FirebaseException catch (e) {
      throw RepositoryException(
        e.message ?? 'Lỗi giao dịch xuất kho',
        code: e.code,
      );
    }
  }

  /// Ghi nhận báo hỏng gạo và trừ tồn kho
  Future<void> confirmDamageReport({
    required DamageReportModel report,
    required String performedBy,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final reportRef = _firestore
            .collection(FirestorePaths.damageReports)
            .doc(report.id);
        final reportSnap = await transaction.get(reportRef);
        if (reportSnap.exists) {
          throw const RepositoryException(
            'Biên bản báo hỏng này đã tồn tại.',
            code: 'already_exists',
          );
        }

        final batchRef =
            _firestore.collection(FirestorePaths.batches).doc(report.batchId);
        final batchSnap = await transaction.get(batchRef);

        if (!batchSnap.exists) {
          throw RepositoryException(
            'Lô hàng ${report.batchCode} không tồn tại.',
            code: 'batch_not_found',
          );
        }

        final batch = _batchMapper.fromMap(
          batchSnap.id,
          batchSnap.data() ?? const {},
        );

        if (batch.quantity < report.quantity - 0.0001) {
          throw const RepositoryException(
            'Số lượng báo hỏng vượt quá số lượng tồn của lô hàng.',
            code: 'insufficient_stock',
          );
        }

        final quantityBefore = batch.quantity;
        final quantityAfter = (quantityBefore - report.quantity).clamp(0.0, double.infinity);

        transaction.update(
          batchRef,
          _batchMapper.toFirestore(
            batch.copyWith(quantity: quantityAfter),
            null,
          ),
        );

        // Lưu báo cáo
        transaction.set(reportRef, _damageMapper.toFirestore(report, null));

        // Tạo stock movement
        final movementId =
            'mov_dmg_${report.id}_${DateTime.now().millisecondsSinceEpoch}';
        final movementRef = _firestore
            .collection(FirestorePaths.stockMovements)
            .doc(movementId);
        final movement = StockMovementModel(
          id: movementId,
          type: 'damage',
          batchId: report.batchId,
          riceId: report.riceId,
          quantityDelta: -report.quantity,
          quantityBefore: quantityBefore,
          quantityAfter: quantityAfter,
          referenceType: 'damage_report',
          referenceId: report.id,
          performedBy: performedBy,
          createdAt: DateTime.now(),
          note: 'Hao hụt/hư hỏng: ${report.reason.label}',
        );
        transaction.set(movementRef, _movementMapper.toFirestore(movement, null));
      });
    } on FirebaseException catch (e) {
      throw RepositoryException(
        e.message ?? 'Lỗi giao dịch báo hỏng gạo',
        code: e.code,
      );
    }
  }

  /// Hoàn tất phiên kiểm kê kho và điều chỉnh tồn
  Future<void> completeInventoryCheck({
    required InventoryCheckSession session,
    required String performedBy,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final checkRef = _firestore
            .collection(FirestorePaths.inventoryChecks)
            .doc(session.id);

        for (final item in session.items) {
          if (!item.hasDifference) continue;

          final batchRef =
              _firestore.collection(FirestorePaths.batches).doc(item.batchId);
          final batchSnap = await transaction.get(batchRef);

          if (!batchSnap.exists) continue;

          final batch = _batchMapper.fromMap(
            batchSnap.id,
            batchSnap.data() ?? const {},
          );

          final quantityBefore = batch.quantity;
          final quantityAfter = item.actualQuantity.clamp(0.0, double.infinity);

          transaction.update(
            batchRef,
            _batchMapper.toFirestore(
              batch.copyWith(quantity: quantityAfter),
              null,
            ),
          );

          // Tạo stock movement cho chênh lệch
          final movementId =
              'mov_chk_${session.id}_${batch.id}_${DateTime.now().millisecondsSinceEpoch}';
          final movementRef = _firestore
              .collection(FirestorePaths.stockMovements)
              .doc(movementId);
          final movement = StockMovementModel(
            id: movementId,
            type: 'inventoryCheck',
            batchId: batch.id,
            riceId: batch.riceId,
            quantityDelta: item.difference,
            quantityBefore: quantityBefore,
            quantityAfter: quantityAfter,
            referenceType: 'inventory_check',
            referenceId: session.id,
            performedBy: performedBy,
            createdAt: DateTime.now(),
            note: 'Điều chỉnh sau kiểm kê ${session.code}: ${item.reason.label}',
          );
          transaction.set(movementRef, _movementMapper.toFirestore(movement, null));
        }

        // Lưu session kiểm kê
        transaction.set(checkRef, _checkMapper.toFirestore(session, null));
      });
    } on FirebaseException catch (e) {
      throw RepositoryException(
        e.message ?? 'Lỗi giao dịch kiểm kê kho',
        code: e.code,
      );
    }
  }
}
