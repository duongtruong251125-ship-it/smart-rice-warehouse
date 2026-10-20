import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/customer_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/damage_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/supplier_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/warehouse_provider.dart';

/// Aggregates warehouse metrics, capacities, and counts for the Warehouse Hub tab.
class WarehouseHubViewModel {
  WarehouseHubViewModel({
    required WarehouseProvider warehouseProvider,
    required BatchProvider batchProvider,
    required RiceProvider riceProvider,
    required SupplierProvider supplierProvider,
    required CustomerProvider customerProvider,
    required DamageProvider damageProvider,
    double maxCapacityTons = 200.0,
  })  : totalKg = batchProvider.totalStock,
        totalTons = batchProvider.totalStock / 1000.0,
        totalBags = (batchProvider.totalStock / 50.0).round(),
        capacityPercent =
            ((batchProvider.totalStock / 1000.0) / maxCapacityTons)
                .clamp(0.0, 1.0),
        locationCount = warehouseProvider.locations.length,
        batchCount = batchProvider.batches.length,
        riceCount = riceProvider.rices.length,
        supplierCount = supplierProvider.suppliers.length,
        customerCount = customerProvider.customers.length,
        damageReportCount = damageProvider.reports.length;

  final double totalKg;
  final double totalTons;
  final int totalBags;
  final double capacityPercent;
  final int locationCount;
  final int batchCount;
  final int riceCount;
  final int supplierCount;
  final int customerCount;
  final int damageReportCount;
}
