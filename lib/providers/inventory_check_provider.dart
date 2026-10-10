import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/data/mock_data.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/models/inventory_check_model.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';

class InventoryCheckProvider extends ChangeNotifier {
  InventoryCheckProvider({
    List<InventoryCheckSession>? initial,
    this.onPersist,
  }) {
    _history = List<InventoryCheckSession>.from(
      initial ?? MockData.initialInventoryChecks,
    );
  }

  late List<InventoryCheckSession> _history;
  InventoryCheckSession? _activeSession;
  final ValueChanged<List<InventoryCheckSession>>? onPersist;

  List<InventoryCheckSession> get history =>
      List<InventoryCheckSession>.unmodifiable(_history);

  InventoryCheckSession? get activeSession => _activeSession;

  bool get hasActiveSession => _activeSession != null;

  /// Bắt đầu một phiên kiểm kê mới
  InventoryCheckSession startNewSession({String createdBy = 'Admin'}) {
    final now = DateTime.now();
    final code =
        'KK-${now.year}${now.month.toString().padLeft(2, '0')}-${(_history.length + 1).toString().padLeft(3, '0')}';
    final session = InventoryCheckSession(
      id: 'session-${DateTime.now().millisecondsSinceEpoch}',
      code: code,
      createdAt: now,
      createdBy: createdBy,
      status: InventoryCheckStatus.inProgress,
      items: const [],
      totalItems: 0,
      totalDifference: 0,
    );
    _activeSession = session;
    notifyListeners();
    return session;
  }

  /// Thêm hoặc cập nhật một lô trong phiên kiểm kê đang diễn ra
  void addOrUpdateItem({
    required BatchModel batch,
    required double actualQuantity,
    InventoryCheckReason reason = InventoryCheckReason.none,
    String? note,
  }) {
    if (_activeSession == null) return;

    final expected = batch.quantity;
    final diff = actualQuantity - expected;
    final item = InventoryCheckItem(
      batchId: batch.id,
      batchCode: batch.code,
      riceName: batch.riceName,
      expectedQuantity: expected,
      actualQuantity: actualQuantity,
      difference: diff,
      reason: reason,
      note: note,
    );

    final currentItems = List<InventoryCheckItem>.from(_activeSession!.items);
    final existingIndex = currentItems.indexWhere((i) => i.batchId == batch.id);

    if (existingIndex >= 0) {
      currentItems[existingIndex] = item;
    } else {
      currentItems.add(item);
    }

    final totalDiff =
        currentItems.fold<double>(0.0, (sum, i) => sum + i.difference);

    _activeSession = _activeSession!.copyWith(
      items: currentItems,
      totalItems: currentItems.length,
      totalDifference: totalDiff,
    );
    notifyListeners();
  }

  /// Xóa một lô khỏi phiên kiểm kê đang làm
  void removeItem(String batchId) {
    if (_activeSession == null) return;

    final currentItems =
        _activeSession!.items.where((i) => i.batchId != batchId).toList();
    final totalDiff =
        currentItems.fold<double>(0.0, (sum, i) => sum + i.difference);

    _activeSession = _activeSession!.copyWith(
      items: currentItems,
      totalItems: currentItems.length,
      totalDifference: totalDiff,
    );
    notifyListeners();
  }

  /// Xác nhận hoàn thành phiên kiểm kê và cập nhật kho thực tế
  bool completeSession({required BatchProvider batchProvider}) {
    if (_activeSession == null || _activeSession!.items.isEmpty) return false;

    final adjustments = <String, double>{
      for (final item in _activeSession!.items)
        if (item.hasDifference) item.batchId: item.actualQuantity,
    };
    if (adjustments.isNotEmpty &&
        !batchProvider.adjustQuantities(adjustments)) {
      return false;
    }

    final completedSession = _activeSession!.copyWith(
      status: InventoryCheckStatus.completed,
      completedAt: DateTime.now(),
    );

    _history.insert(0, completedSession);
    onPersist?.call(history);
    _activeSession = null;
    notifyListeners();
    return true;
  }

  /// Hủy phiên kiểm kê đang làm
  void cancelActiveSession() {
    _activeSession = null;
    notifyListeners();
  }

  InventoryCheckSession? findById(String id) {
    if (_activeSession?.id == id) return _activeSession;
    try {
      return _history.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}
