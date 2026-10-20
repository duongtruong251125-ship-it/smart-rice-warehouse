import 'package:cloud_functions/cloud_functions.dart';
import 'package:smart_rice_warehouse/logic/contracts/inventory_transactions.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/repository_exception.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/damage_report_model.dart';
import 'package:smart_rice_warehouse/logic/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/inventory_check_model.dart';

typedef InventoryCallable = Future<void> Function(
    String name, Map<String, dynamic> payload);

/// Cloud stock writes go through the trusted server. Never fall back to a
/// direct Firestore write if the callable is unavailable or not deployed.
class CallableInventoryTransactions implements InventoryTransactions {
  CallableInventoryTransactions({
    FirebaseFunctions? functions,
    InventoryCallable? invoke,
  }) : _invoke = invoke ??
            ((name, payload) async {
              final service = functions ??
                  FirebaseFunctions.instanceFor(region: 'us-central1');
              await service.httpsCallable(name).call<void>(payload);
            });

  final InventoryCallable _invoke;

  static Map<String, Object?> _wire(Map<String, Object?> json) {
    const dates = {
      'date',
      'importDate',
      'manufactureDate',
      'expiryDate',
      'createdAt',
      'completedAt'
    };
    return json.map((key, value) => MapEntry(
        key,
        dates.contains(key) && value is String
            ? DateTime.parse(value).toUtc().toIso8601String()
            : value));
  }

  Future<void> _call(String name, Map<String, dynamic> payload) async {
    try {
      await _invoke(name, payload);
    } on FirebaseFunctionsException catch (error) {
      throw RepositoryException(
        error.message ?? 'Không thể xác nhận giao dịch trên máy chủ.',
        code: error.code,
        cause: error,
      );
    }
  }

  @override
  Future<void> confirmImportReceipt({
    required ImportReceiptModel receipt,
    required BatchModel batchToCreateOrUpdate,
    required String performedBy,
  }) =>
      _call('confirmImport', {
        'receipt': _wire(receipt.toJson()),
        'batch': _wire(batchToCreateOrUpdate.toJson()),
      });

  @override
  Future<void> confirmExportReceipt({
    required ExportReceiptModel receipt,
    required String performedBy,
  }) =>
      _call('confirmExport', {'receipt': _wire(receipt.toJson())});

  @override
  Future<void> confirmDamageReport({
    required DamageReportModel report,
    required String performedBy,
  }) =>
      _call('confirmDamage', {'report': _wire(report.toJson())});

  @override
  Future<void> completeInventoryCheck({
    required InventoryCheckSession session,
    required String performedBy,
  }) =>
      _call('completeCheck', {'session': _wire(session.toJson())});
}
