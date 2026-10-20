import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/customer_model.dart';
import 'package:smart_rice_warehouse/logic/models/damage_report_model.dart';
import 'package:smart_rice_warehouse/logic/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/inventory_check_model.dart';
import 'package:smart_rice_warehouse/logic/models/rice_characteristic_model.dart';
import 'package:smart_rice_warehouse/logic/models/rice_model.dart';
import 'package:smart_rice_warehouse/logic/models/supplier_model.dart';
import 'package:smart_rice_warehouse/logic/models/warehouse_location_model.dart';

/// Contract providing initial or fallback catalog and transaction datasets
/// without hardcoding the data layer inside logic.
abstract interface class InitialDataProvider {
  List<BatchModel> get batches;
  List<RiceModel> get rices;
  List<SupplierModel> get suppliers;
  List<CustomerModel> get customers;
  List<WarehouseLocationModel> get warehouseLocations;
  List<ImportReceiptModel> get importReceipts;
  List<ExportReceiptModel> get exportReceipts;
  List<DamageReportModel> get damageReports;
  List<InventoryCheckSession> get inventoryChecks;
  List<RiceCharacteristicModel> get riceCharacteristics;
}

/// Registry allowing composition root or test environments to provide default data.
abstract final class DefaultDataRegistry {
  static InitialDataProvider? provider;
}
