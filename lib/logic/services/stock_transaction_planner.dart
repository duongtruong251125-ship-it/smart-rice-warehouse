import 'package:smart_rice_warehouse/logic/contracts/repositories/repository_exception.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/inventory_check_model.dart';
import 'package:smart_rice_warehouse/logic/models/stock_movement_model.dart';

/// Error codes produced while validating a stock transaction.
abstract final class StockTransactionError {
  static const alreadyConfirmed = 'already_confirmed';
  static const batchNotFound = 'batch_not_found';
  static const batchUnavailable = 'batch_unavailable';
  static const insufficientStock = 'insufficient_stock';
  static const invalidQuantity = 'invalid_quantity';
  static const allocationMismatch = 'allocation_mismatch';
  static const riceMismatch = 'rice_mismatch';
  static const stockChanged = 'stock_changed';
  static const batchCodeConflict = 'batch_code_conflict';
  static const duplicateBatchCode = 'duplicate_batch_code';
  static const invalidSession = 'invalid_session';
}

/// One batch document that a transaction will create or update.
class PlannedBatchWrite {
  const PlannedBatchWrite({
    required this.batch,
    required this.isNew,
    required this.quantityBefore,
  });

  final BatchModel batch;
  final bool isNew;
  final double quantityBefore;

  double get quantityAfter => batch.quantity;
}

/// All writes of a stock transaction, produced only after every read and
/// every validation has succeeded. A storage adapter applies the whole plan
/// in one atomic transaction or nothing at all.
class StockTransactionPlan {
  const StockTransactionPlan({
    required this.batchWrites,
    required this.movements,
  });

  final List<PlannedBatchWrite> batchWrites;
  final List<StockMovementModel> movements;
}

/// Pure stock-transaction rules shared by every storage implementation.
///
/// Inputs are the state read inside the transaction; the planner never
/// performs I/O, so concurrent changes are detected by re-running it on the
/// fresh state the database provides when it retries a transaction.
class StockTransactionPlanner {
  const StockTransactionPlanner();

  static const double _epsilon = 0.0001;

  /// Stable key used to reserve a batch code across devices.
  static String batchCodeKey(String code) {
    final normalized = code.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw const RepositoryException(
        'Mã lô không được để trống.',
        code: StockTransactionError.invalidQuantity,
      );
    }
    return normalized.replaceAll('/', '_');
  }

  static bool sameBatchCode(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

  StockTransactionPlan planImport({
    required ImportReceiptModel receipt,
    required BatchModel requestedBatch,
    required bool receiptExists,
    required Iterable<BatchModel> existingBatchesWithCode,
    required String performedBy,
    required DateTime now,
  }) {
    if (receiptExists) {
      throw const RepositoryException(
        'Phiếu nhập kho này đã được xác nhận trước đó.',
        code: StockTransactionError.alreadyConfirmed,
      );
    }
    _requirePositive(receipt.quantity, 'Số lượng nhập');
    if ((receipt.quantity - requestedBatch.quantity).abs() > _epsilon ||
        receipt.riceId != requestedBatch.riceId ||
        !sameBatchCode(receipt.batchCode, requestedBatch.code)) {
      throw const RepositoryException(
        'Phiếu nhập và lô hàng không khớp số lượng, loại gạo hoặc mã lô.',
        code: StockTransactionError.allocationMismatch,
      );
    }

    final matches = <String, BatchModel>{
      for (final batch in existingBatchesWithCode)
        if (sameBatchCode(batch.code, requestedBatch.code)) batch.id: batch,
    };
    if (matches.length > 1) {
      throw RepositoryException(
        'Mã lô ${requestedBatch.code} đang bị trùng ở ${matches.length} lô. '
        'Cần quản trị viên gộp dữ liệu trước khi nhập bổ sung.',
        code: StockTransactionError.duplicateBatchCode,
      );
    }

    final PlannedBatchWrite write;
    if (matches.isEmpty) {
      write = PlannedBatchWrite(
        batch: requestedBatch,
        isNew: true,
        quantityBefore: 0,
      );
    } else {
      final existing = matches.values.single;
      final sameLot = existing.riceId == requestedBatch.riceId &&
          (existing.supplierId ?? '') == (requestedBatch.supplierId ?? '') &&
          _sameDay(existing.manufactureDate, requestedBatch.manufactureDate) &&
          _sameDay(existing.expiryDate, requestedBatch.expiryDate);
      if (!sameLot) {
        throw RepositoryException(
          'Mã lô ${existing.code} đã thuộc lô khác (khác gạo, nhà cung cấp '
          'hoặc ngày sản xuất/hạn dùng).',
          code: StockTransactionError.batchCodeConflict,
        );
      }
      write = PlannedBatchWrite(
        batch:
            existing.copyWith(quantity: existing.quantity + receipt.quantity),
        isNew: false,
        quantityBefore: existing.quantity,
      );
    }

    return StockTransactionPlan(
      batchWrites: [write],
      movements: [
        StockMovementModel(
          id: 'mov_imp_${receipt.id}',
          type: 'import',
          batchId: write.batch.id,
          riceId: receipt.riceId,
          quantityDelta: receipt.quantity,
          quantityBefore: write.quantityBefore,
          quantityAfter: write.quantityAfter,
          referenceType: 'import_receipt',
          referenceId: receipt.id,
          performedBy: performedBy,
          createdAt: now,
          note: 'Nhập kho theo phiếu ${receipt.code}',
        ),
      ],
    );
  }

  StockTransactionPlan planExport({
    required ExportReceiptModel receipt,
    required bool receiptExists,
    required Map<String, BatchModel?> batchesById,
    required String performedBy,
    required DateTime now,
  }) {
    if (receiptExists) {
      throw const RepositoryException(
        'Phiếu xuất kho này đã được xác nhận trước đó.',
        code: StockTransactionError.alreadyConfirmed,
      );
    }
    _requirePositive(receipt.quantity, 'Số lượng xuất');
    final requested = requestedQuantities(receipt);
    final total = requested.values.fold<double>(0, (sum, q) => sum + q);
    if ((total - receipt.quantity).abs() > _epsilon) {
      throw const RepositoryException(
        'Tổng phân bổ lô không bằng số lượng xuất.',
        code: StockTransactionError.allocationMismatch,
      );
    }

    final today = DateTime(now.year, now.month, now.day);
    // Validate every batch before producing any write.
    for (final entry in requested.entries) {
      final batch = batchesById[entry.key];
      if (batch == null) {
        throw RepositoryException(
          'Lô hàng ${entry.key} không tồn tại trên hệ thống.',
          code: StockTransactionError.batchNotFound,
        );
      }
      if (batch.riceId != receipt.riceId) {
        throw RepositoryException(
          'Lô ${batch.code} không thuộc loại gạo của phiếu xuất.',
          code: StockTransactionError.riceMismatch,
        );
      }
      final expiry = DateTime(
        batch.expiryDate.year,
        batch.expiryDate.month,
        batch.expiryDate.day,
      );
      if (batch.status == BatchStatus.qualityHold) {
        throw RepositoryException(
          'Lô ${batch.code} đang tạm giữ, không thể xuất.',
          code: StockTransactionError.batchUnavailable,
        );
      }
      if (batch.status == BatchStatus.expired || expiry.isBefore(today)) {
        throw RepositoryException(
          'Lô ${batch.code} đã hết hạn, không thể xuất.',
          code: StockTransactionError.batchUnavailable,
        );
      }
      if (batch.quantity < entry.value - _epsilon) {
        throw RepositoryException(
          'Lô ${batch.code} không đủ tồn kho (còn ${batch.quantity}kg, '
          'cần xuất ${entry.value}kg).',
          code: StockTransactionError.insufficientStock,
        );
      }
    }

    final writes = <PlannedBatchWrite>[];
    final movements = <StockMovementModel>[];
    for (final entry in requested.entries) {
      final batch = batchesById[entry.key]!;
      final before = batch.quantity;
      var after = before - entry.value;
      if (after.abs() < _epsilon) after = 0;
      final status = after <= 0
          ? BatchStatus.qualityHold
          : (after <= 100 ? BatchStatus.lowStock : BatchStatus.available);
      writes.add(PlannedBatchWrite(
        batch: batch.copyWith(quantity: after, status: status),
        isNew: false,
        quantityBefore: before,
      ));
      movements.add(StockMovementModel(
        id: 'mov_exp_${receipt.id}_${batch.id}',
        type: 'export',
        batchId: batch.id,
        riceId: receipt.riceId,
        quantityDelta: -entry.value,
        quantityBefore: before,
        quantityAfter: after,
        referenceType: 'export_receipt',
        referenceId: receipt.id,
        performedBy: performedBy,
        createdAt: now,
        note: 'Xuất kho cho khách ${receipt.customerName} '
            'theo phiếu ${receipt.code}',
      ));
    }
    return StockTransactionPlan(batchWrites: writes, movements: movements);
  }

  /// Quantity requested from each batch; repeated allocations are summed.
  Map<String, double> requestedQuantities(ExportReceiptModel receipt) {
    if (receipt.allocations.isEmpty) {
      throw const RepositoryException(
        'Phiếu xuất chưa có phân bổ lô hàng.',
        code: StockTransactionError.allocationMismatch,
      );
    }
    final requested = <String, double>{};
    for (final allocation in receipt.allocations) {
      _requirePositive(allocation.allocatedQuantity, 'Số lượng phân bổ');
      requested.update(
        allocation.batchId,
        (value) => value + allocation.allocatedQuantity,
        ifAbsent: () => allocation.allocatedQuantity,
      );
    }
    return requested;
  }

  /// Batches whose stock an inventory check will adjust.
  Set<String> adjustedBatchIds(InventoryCheckSession session) => {
        for (final item in session.items)
          if (item.hasDifference) item.batchId,
      };

  StockTransactionPlan planInventoryCheck({
    required InventoryCheckSession session,
    required InventoryCheckStatus? storedStatus,
    required Map<String, BatchModel?> batchesById,
    required String performedBy,
    required DateTime now,
  }) {
    if (storedStatus == InventoryCheckStatus.completed) {
      throw const RepositoryException(
        'Phiên kiểm kê này đã được hoàn tất trước đó.',
        code: StockTransactionError.alreadyConfirmed,
      );
    }
    if (session.items.isEmpty) {
      throw const RepositoryException(
        'Phiên kiểm kê chưa có lô hàng nào.',
        code: StockTransactionError.invalidSession,
      );
    }
    final seen = <String>{};
    for (final item in session.items) {
      if (!seen.add(item.batchId)) {
        throw RepositoryException(
          'Lô ${item.batchCode} xuất hiện nhiều lần trong phiên kiểm kê.',
          code: StockTransactionError.invalidSession,
        );
      }
      if (!item.actualQuantity.isFinite || item.actualQuantity < 0) {
        throw RepositoryException(
          'Số lượng thực tế của lô ${item.batchCode} không hợp lệ.',
          code: StockTransactionError.invalidQuantity,
        );
      }
    }

    final adjusted = session.items.where((item) => item.hasDifference);
    for (final item in adjusted) {
      final batch = batchesById[item.batchId];
      if (batch == null) {
        throw RepositoryException(
          'Lô ${item.batchCode} không còn tồn tại; không thể điều chỉnh tồn.',
          code: StockTransactionError.batchNotFound,
        );
      }
      if ((batch.quantity - item.expectedQuantity).abs() > 0.001) {
        throw RepositoryException(
          'Tồn kho lô ${item.batchCode} đã thay đổi từ '
          '${item.expectedQuantity}kg thành ${batch.quantity}kg sau khi đếm. '
          'Vui lòng kiểm đếm lại lô này.',
          code: StockTransactionError.stockChanged,
        );
      }
    }

    final writes = <PlannedBatchWrite>[];
    final movements = <StockMovementModel>[];
    for (final item in adjusted) {
      final batch = batchesById[item.batchId]!;
      writes.add(PlannedBatchWrite(
        batch: batch.copyWith(quantity: item.actualQuantity),
        isNew: false,
        quantityBefore: batch.quantity,
      ));
      movements.add(StockMovementModel(
        id: 'mov_chk_${session.id}_${batch.id}',
        type: 'inventoryCheck',
        batchId: batch.id,
        riceId: batch.riceId,
        quantityDelta: item.actualQuantity - batch.quantity,
        quantityBefore: batch.quantity,
        quantityAfter: item.actualQuantity,
        referenceType: 'inventory_check',
        referenceId: session.id,
        performedBy: performedBy,
        createdAt: now,
        note: 'Điều chỉnh sau kiểm kê ${session.code}: ${item.reason.label}',
      ));
    }
    return StockTransactionPlan(batchWrites: writes, movements: movements);
  }

  void _requirePositive(double value, String label) {
    if (!value.isFinite || value <= 0) {
      throw RepositoryException(
        '$label phải lớn hơn 0.',
        code: StockTransactionError.invalidQuantity,
      );
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
