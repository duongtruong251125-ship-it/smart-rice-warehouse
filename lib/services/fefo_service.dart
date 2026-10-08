import 'package:smart_rice_warehouse/models/batch_allocation_model.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';

class FefoAllocationResult {
  const FefoAllocationResult({
    required this.isSuccess,
    required this.allocations,
    required this.requestedQuantity,
    required this.allocatedQuantity,
    this.errorMessage,
  });

  final bool isSuccess;
  final List<BatchAllocation> allocations;
  final double requestedQuantity;
  final double allocatedQuantity;
  final String? errorMessage;

  factory FefoAllocationResult.failure({
    required double requestedQuantity,
    required String errorMessage,
    double allocatedQuantity = 0,
    List<BatchAllocation> allocations = const [],
  }) {
    return FefoAllocationResult(
      isSuccess: false,
      allocations: allocations,
      requestedQuantity: requestedQuantity,
      allocatedQuantity: allocatedQuantity,
      errorMessage: errorMessage,
    );
  }

  factory FefoAllocationResult.success({
    required double requestedQuantity,
    required List<BatchAllocation> allocations,
  }) {
    final totalAllocated = allocations.fold(
      0.0,
      (sum, item) => sum + item.allocatedQuantity,
    );
    return FefoAllocationResult(
      isSuccess: true,
      allocations: allocations,
      requestedQuantity: requestedQuantity,
      allocatedQuantity: totalAllocated,
    );
  }
}

class FefoService {
  const FefoService();

  /// Phân bổ số lượng xuất kho theo nguyên tắc FEFO (First Expired, First Out)
  /// Trả về kết quả phân bổ trước khi cập nhật dữ liệu.
  FefoAllocationResult allocate({
    required List<BatchModel> batches,
    required String riceId,
    required double quantity,
    DateTime? currentDate,
  }) {
    if (quantity <= 0) {
      return FefoAllocationResult.failure(
        requestedQuantity: quantity,
        errorMessage: 'Số lượng xuất phải lớn hơn 0',
      );
    }

    final now = currentDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 1. Lọc các lô hợp lệ của loại gạo: quantity > 0, chưa hết hạn, status != expired
    final validBatches = batches.where((batch) {
      if (batch.riceId != riceId) return false;
      if (batch.quantity <= 0) return false;
      if (batch.status == BatchStatus.expired) return false;

      final expiry = DateTime(
        batch.expiryDate.year,
        batch.expiryDate.month,
        batch.expiryDate.day,
      );
      return !expiry.isBefore(today);
    }).toList();

    if (validBatches.isEmpty) {
      return FefoAllocationResult.failure(
        requestedQuantity: quantity,
        errorMessage: 'Không có lô hàng hợp lệ hoặc còn hạn để xuất',
      );
    }

    // 2. Sắp xếp theo hạn sử dụng (expiryDate) tăng dần (FEFO)
    // Nếu cùng hạn sử dụng, ưu tiên lô nhập trước (importDate tăng dần)
    validBatches.sort((a, b) {
      final expiryComp = a.expiryDate.compareTo(b.expiryDate);
      if (expiryComp != 0) return expiryComp;
      return a.importDate.compareTo(b.importDate);
    });

    // 3. Kiểm tra tổng số lượng khả dụng
    final totalAvailable = validBatches.fold(
      0.0,
      (sum, batch) => sum + batch.quantity,
    );

    const tolerance = 0.000000001;
    if (totalAvailable + tolerance < quantity) {
      return FefoAllocationResult.failure(
        requestedQuantity: quantity,
        errorMessage:
            'Tồn kho khả dụng không đủ (Cần: $quantity, Khả dụng: $totalAvailable)',
      );
    }

    // 4. Phân bổ quantity theo thứ tự FEFO
    var remainingNeeded = quantity;
    final allocations = <BatchAllocation>[];

    for (final batch in validBatches) {
      if (remainingNeeded <= tolerance) break;

      final take = batch.quantity < remainingNeeded
          ? batch.quantity
          : remainingNeeded;
      final remainingInBatch = batch.quantity - take;

      allocations.add(
        BatchAllocation(
          batchId: batch.id,
          batchCode: batch.code,
          allocatedQuantity: take,
          batchInitialQuantity: batch.quantity,
          batchRemainingQuantity: remainingInBatch,
          expiryDate: batch.expiryDate,
        ),
      );

      remainingNeeded -= take;
    }

    return FefoAllocationResult.success(
      requestedQuantity: quantity,
      allocations: allocations,
    );
  }
}
