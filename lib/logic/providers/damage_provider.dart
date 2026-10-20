import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/logic/contracts/initial_data_provider.dart';
import 'package:smart_rice_warehouse/logic/models/damage_report_model.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/crud_repository.dart';
import 'package:smart_rice_warehouse/logic/contracts/inventory_transactions.dart';

class DamageProvider extends ChangeNotifier {
  DamageProvider({
    List<DamageReportModel>? initial,
    this.onPersist,
    this.repository,
    this.transactionRepository,
  }) {
    _reports = List<DamageReportModel>.from(
      initial ?? DefaultDataRegistry.provider?.damageReports ?? const [],
    );
    for (final report in _reports) {
      if (report.imagePath?.isNotEmpty == true) {
        _localImagePaths[report.id] = report.imagePath!;
      }
    }
    if (repository != null) {
      _subscribeToFirestore();
    }
  }

  late List<DamageReportModel> _reports;
  final Map<String, String> _localImagePaths = {};
  final ValueChanged<List<DamageReportModel>>? onPersist;
  final CrudRepository<DamageReportModel>? repository;
  final InventoryTransactions? transactionRepository;
  StreamSubscription<List<DamageReportModel>>? _subscription;
  bool _isLoading = false;
  String? _errorMessage;

  List<DamageReportModel> get reports =>
      List<DamageReportModel>.unmodifiable(_reports);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get usesFirestore => repository != null;

  static String resolveDefaultDamageImage(DamageReportModel report) {
    if (report.imagePath?.trim().isNotEmpty == true) {
      return report.imagePath!;
    }
    switch (report.reason) {
      case DamageReason.baoRach:
        return 'assets/images/damage/torn-sack.jpg';
      case DamageReason.moc:
      case DamageReason.baoUot:
        return 'assets/images/damage/wet-mold.jpg';
      case DamageReason.conTrung:
      case DamageReason.haoHut:
      case DamageReason.khac:
        return 'assets/images/damage/rice-weevils.jpg';
    }
  }

  void _subscribeToFirestore() {
    _isLoading = true;
    _subscription = repository!.watchAll().listen(
      (remoteReports) {
        _reports
          ..clear()
          ..addAll(
            remoteReports.map(
              (report) => report.copyWith(
                imagePath: _localImagePaths[report.id] ??
                    resolveDefaultDamageImage(report),
              ),
            ),
          );
        _isLoading = false;
        _errorMessage = null;
        _persist();
        notifyListeners();
      },
      onError: (Object error) {
        _isLoading = false;
        _errorMessage = 'Không thể đồng bộ báo cáo hư hỏng: $error';
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

  double get totalDamagedWeight =>
      _reports.fold<double>(0.0, (sum, r) => sum + r.quantity);

  Future<bool> createDamageReportOnline({
    required DamageReportModel report,
    String performedBy = 'system',
  }) async {
    if (transactionRepository == null) {
      return false;
    }
    try {
      await transactionRepository!.confirmDamageReport(
        report: report,
        performedBy: performedBy,
      );
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = 'Không thể tạo biên bản báo hỏng: $error';
      notifyListeners();
      return false;
    }
  }

  /// Tạo và xác nhận báo hỏng -> Giảm tồn kho của Batch tương ứng
  Future<bool> createDamageReport({
    required String batchId,
    required String batchCode,
    required String riceId,
    required String riceName,
    required double quantity,
    required DamageReason reason,
    required BatchProvider batchProvider,
    String? note,
    String? imagePath,
    String createdBy = 'Admin',
  }) async {
    if (quantity <= 0) return false;

    final batch = batchProvider.findById(batchId);
    if (batch == null || batch.quantity < quantity) {
      return false; // Số lượng báo hỏng vượt quá tồn hiện có
    }

    final now = DateTime.now();
    final code =
        'BH-${now.year}${now.month.toString().padLeft(2, '0')}-${(_reports.length + 1).toString().padLeft(3, '0')}';

    final report = DamageReportModel(
      id: 'damage-${now.millisecondsSinceEpoch}',
      code: code,
      batchId: batchId,
      batchCode: batchCode,
      riceId: riceId,
      riceName: riceName,
      quantity: quantity,
      reason: reason,
      note: note,
      imagePath: imagePath,
      createdBy: createdBy,
      createdAt: now,
      status: DamageReportStatus.confirmed,
    );

    if (transactionRepository != null) {
      return await createDamageReportOnline(
        report: report,
        performedBy: createdBy,
      );
    }

    final reduced = batchProvider.reportDamage(
      batchId: batchId,
      damagedQuantity: quantity,
    );
    if (!reduced) return false;

    _reports.insert(0, report);
    _persist();
    notifyListeners();
    return true;
  }

  List<DamageReportModel> filter({DamageReason? reason, String? keyword}) {
    return _reports.where((r) {
      if (reason != null && r.reason != reason) return false;
      if (keyword != null && keyword.trim().isNotEmpty) {
        final q = keyword.trim().toLowerCase();
        final matchCode = r.code.toLowerCase().contains(q);
        final matchBatch = r.batchCode.toLowerCase().contains(q);
        final matchRice = r.riceName.toLowerCase().contains(q);
        if (!matchCode && !matchBatch && !matchRice) return false;
      }
      return true;
    }).toList();
  }

  DamageReportModel? findById(String id) {
    try {
      return _reports.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  List<DamageReportModel> filterByBatch(String batchId) {
    return _reports.where((r) => r.batchId == batchId).toList();
  }

  List<DamageReportModel> filterByRice(String riceId) {
    return _reports.where((r) => r.riceId == riceId).toList();
  }

  void _persist() => onPersist?.call(reports);

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
