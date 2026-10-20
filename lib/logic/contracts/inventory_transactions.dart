import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/damage_report_model.dart';
import 'package:smart_rice_warehouse/logic/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/inventory_check_model.dart';

/// Warehouse transaction API, independent of a Firestore implementation.
abstract interface class InventoryTransactions {
  Future<void> confirmImportReceipt({
    required ImportReceiptModel receipt,
    required BatchModel batchToCreateOrUpdate,
    required String performedBy,
  });
  Future<void> confirmExportReceipt({
    required ExportReceiptModel receipt,
    required String performedBy,
  });
  Future<void> confirmDamageReport({
    required DamageReportModel report,
    required String performedBy,
  });
  Future<void> completeInventoryCheck({
    required InventoryCheckSession session,
    required String performedBy,
  });
}
