import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/logic/contracts/initial_data_provider.dart';
import 'package:smart_rice_warehouse/logic/contracts/inventory_transactions.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/crud_repository.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/inventory_check_model.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';

class InventoryCheckProvider extends ChangeNotifier {
  InventoryCheckProvider({
    List<InventoryCheckSession>? initial,
    this.onPersist,
    this.repository,
    this.transactionRepository,
  }) {
    _history = List<InventoryCheckSession>.from(
      initial ?? DefaultDataRegistry.provider?.inventoryChecks ?? const [],
    );
    if (repository != null) {
      _subscribeToFirestore();
    }
  }

  late List<InventoryCheckSession> _history;
  InventoryCheckSession? _activeSession;
  final ValueChanged<List<InventoryCheckSession>>? onPersist;
  final CrudRepository<InventoryCheckSession>? repository;
  final InventoryTransactions? transactionRepository;
  StreamSubscription<List<InventoryCheckSession>>? _subscription;
  bool _isLoading = false;
  String? _errorMessage;

  List<InventoryCheckSession> get history =>
      List<InventoryCheckSession>.unmodifiable(_history);
  InventoryCheckSession? get activeSession => _activeSession;
  bool get hasActiveSession => _activeSession != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get usesFirestore => repository != null;

  void _subscribeToFirestore() {
    _isLoading = true;
    _subscription = repository!.watchAll().listen(
      (remoteSessions) {
        _history
          ..clear()
          ..addAll(remoteSessions);
        _isLoading = false;
        _errorMessage = null;
        onPersist?.call(history);
        notifyListeners();
      },
      onError: (Object error) {
        _isLoading = false;
        _errorMessage = 'Không thể đồng bộ lịch sử kiểm kê: $error';
        notifyListeners();
      },
    );
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  void retrySync() {
    _errorMessage = null;
    if (repository != null) {
      _subscription?.cancel();
      _subscribeToFirestore();
      notifyListeners();
    } else {
      notifyListeners();
    }
  }

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

  Future<bool> completeSessionOnline({String performedBy = 'system'}) async {
    if (_activeSession == null || _activeSession!.items.isEmpty) return false;
    if (transactionRepository == null) return false;

    final completedSession = _activeSession!.copyWith(
      status: InventoryCheckStatus.completed,
      completedAt: DateTime.now(),
    );

    try {
      await transactionRepository!.completeInventoryCheck(
        session: completedSession,
        performedBy: performedBy,
      );
      _history.insert(0, completedSession);
      onPersist?.call(history);
      _activeSession = null;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = 'Không thể hoàn tất kiểm kê: $error';
      notifyListeners();
      return false;
    }
  }

  /// Xác nhận hoàn thành phiên kiểm kê và cập nhật kho thực tế
  Future<bool> completeSession({
    required BatchProvider batchProvider,
    String performedBy = 'system',
  }) async {
    if (_activeSession == null || _activeSession!.items.isEmpty) return false;

    if (transactionRepository != null) {
      return await completeSessionOnline(performedBy: performedBy);
    }

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

  InventoryCheckSession? findById(String id) {
    if (_activeSession?.id == id) return _activeSession;
    try {
      return _history.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Retains the recorded batch details when the original batch is unavailable.
  BatchModel batchForItem(InventoryCheckItem item, BatchProvider batches) {
    final now = DateTime.now();
    return batches.findById(item.batchId) ??
        BatchModel(
          id: item.batchId,
          code: item.batchCode,
          riceId: '',
          riceName: item.riceName,
          quantity: item.expectedQuantity,
          importDate: now,
          manufactureDate: now,
          expiryDate: now,
          status: BatchStatus.available,
        );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
