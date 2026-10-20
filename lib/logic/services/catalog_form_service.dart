import 'package:uuid/uuid.dart';
import 'package:smart_rice_warehouse/logic/models/customer_model.dart';
import 'package:smart_rice_warehouse/logic/models/rice_model.dart';
import 'package:smart_rice_warehouse/logic/models/rice_characteristic_model.dart';
import 'package:smart_rice_warehouse/logic/models/supplier_model.dart';
import 'package:smart_rice_warehouse/logic/models/warehouse_location_model.dart';
import 'package:smart_rice_warehouse/logic/providers/customer_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/rice_characteristic_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/supplier_provider.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/export_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/warehouse_provider.dart';
import 'package:smart_rice_warehouse/logic/services/media_service.dart';

class CatalogFormService {
  CatalogFormService({String Function()? newId})
      : _newId = newId ?? const Uuid().v4;
  final String Function() _newId;

  Future<bool> saveCustomer({
    required CustomerProvider provider,
    CustomerModel? original,
    required String name,
    required String phone,
    required String address,
    required CustomerType type,
    required bool isActive,
  }) {
    final customer = CustomerModel(
        id: original?.id ?? _newId(),
        name: name.trim(),
        phone: phone.trim(),
        address: address.trim(),
        customerType: type,
        isActive: isActive);
    return original == null
        ? provider.addCustomerOnline(customer)
        : provider.updateCustomerOnline(customer);
  }

  Future<bool> saveSupplier({
    required SupplierProvider provider,
    SupplierModel? original,
    required String name,
    required String phone,
    required String email,
    required String address,
    required String taxCode,
    required bool isActive,
  }) {
    final supplier = SupplierModel(
        id: original?.id ?? _newId(),
        name: name.trim(),
        phone: phone.trim(),
        email: email.trim(),
        address: address.trim(),
        taxCode: taxCode.trim(),
        isActive: isActive);
    return original == null
        ? provider.addSupplierOnline(supplier)
        : provider.updateSupplierOnline(supplier);
  }

  Future<bool> saveRice({
    required RiceProvider provider,
    RiceModel? original,
    required String code,
    required String name,
    required String category,
    required String unit,
    required double purchasePrice,
    required double sellingPrice,
    required double minimumStock,
    required String description,
    required bool isActive,
    required String? imagePath,
    required List<String> characteristicIds,
  }) async {
    var savedPath = imagePath;
    String? oldImageToDelete;
    if (imagePath != original?.imagePath) {
      if (imagePath != null && imagePath.isNotEmpty) {
        savedPath =
            await MediaService.save(imagePath, subDirectory: 'rice_images');
        oldImageToDelete = original?.imagePath;
      } else if (original?.imagePath != null) {
        oldImageToDelete = original!.imagePath;
        savedPath = null;
      }
    }
    final rice = RiceModel(
        id: original?.id ?? _newId(),
        code: code.trim(),
        name: name.trim(),
        category: category.trim(),
        unit: unit.trim(),
        purchasePrice: purchasePrice,
        sellingPrice: sellingPrice,
        minimumStock: minimumStock,
        description: description.trim(),
        isActive: isActive,
        imagePath: savedPath,
        characteristicIds: List.of(characteristicIds));
    final saved = original == null
        ? await provider.addRiceOnline(rice)
        : await provider.updateRiceOnline(rice);
    if (!saved) {
      if (savedPath != null && savedPath != original?.imagePath) {
        await MediaService.delete(savedPath);
      }
      return false;
    }
    if (oldImageToDelete != null && oldImageToDelete != savedPath) {
      await MediaService.delete(oldImageToDelete);
    }
    return true;
  }

  Future<bool> saveCharacteristic({
    required RiceCharacteristicProvider provider,
    RiceCharacteristicModel? original,
    required String name,
    required String description,
    required int color,
  }) {
    final item = original?.copyWith(
            name: name.trim(),
            description: description.trim(),
            colorValue: color) ??
        RiceCharacteristicModel(
            id: 'char-${_newId().substring(0, 8)}',
            name: name.trim(),
            description: description.trim(),
            colorValue: color,
            isDefault: false);
    return original == null
        ? provider.addCharacteristicOnline(item)
        : provider.updateCharacteristicOnline(item);
  }

  Future<({bool success, String? message})> deleteCharacteristic({
    required RiceProvider rices,
    required RiceCharacteristicProvider characteristics,
    required String id,
  }) async {
    if (!await rices.removeCharacteristicFromAllOnline(id)) {
      return (
        success: false,
        message: rices.errorMessage ?? 'Không thể gỡ đặc tính khỏi sản phẩm.'
      );
    }
    final deleted = await characteristics.deleteCharacteristicOnline(id);
    return (
      success: deleted,
      message: deleted
          ? null
          : characteristics.errorMessage ?? 'Không thể xóa đặc tính.'
    );
  }

  Future<bool> addLocation({
    required WarehouseProvider provider,
    required String zone,
    required String rack,
    required String shelf,
    required String code,
    required double capacity,
    required String description,
  }) =>
      provider.addLocationOnline(WarehouseLocationModel(
          id: 'loc-${DateTime.now().millisecondsSinceEpoch}',
          zone: zone.trim(),
          rack: rack.trim(),
          shelf: shelf.trim(),
          code: code.trim(),
          capacity: capacity,
          description: description.trim().isEmpty ? null : description.trim()));

  Future<({bool success, String message})> deleteRice({
    required RiceProvider riceProvider,
    required BatchProvider batchProvider,
    required RiceModel rice,
  }) async {
    final isReferenced = batchProvider.batches.any((b) => b.riceId == rice.id);
    if (isReferenced) {
      return (
        success: false,
        message: 'Không thể xóa: loại gạo đang được sử dụng trong lô hàng.',
      );
    }
    final deleted = await riceProvider.deleteRiceOnline(rice.id);
    return (
      success: deleted,
      message: deleted ? 'Đã xóa gạo' : 'Không thể xóa loại gạo này.',
    );
  }

  Future<({bool success, String message})> deleteSupplier({
    required SupplierProvider supplierProvider,
    required BatchProvider batchProvider,
    required SupplierModel supplier,
  }) async {
    final isReferenced =
        batchProvider.batches.any((b) => b.supplierId == supplier.id);
    if (isReferenced) {
      return (
        success: false,
        message: 'Không thể xóa: nhà cung cấp đang có lô hàng liên quan.',
      );
    }
    final deleted = await supplierProvider.deleteSupplierOnline(supplier.id);
    return (
      success: deleted,
      message:
          deleted ? 'Đã xóa nhà cung cấp' : 'Không thể xóa nhà cung cấp này.',
    );
  }

  Future<({bool success, String message})> deleteCustomer({
    required CustomerProvider customerProvider,
    required ExportProvider exportProvider,
    required CustomerModel customer,
  }) async {
    final isReferenced =
        exportProvider.receipts.any((r) => r.customerId == customer.id);
    if (isReferenced) {
      return (
        success: false,
        message: 'Không thể xóa: khách hàng đã có phiếu xuất liên quan.',
      );
    }
    final deleted = await customerProvider.deleteCustomerOnline(customer.id);
    return (
      success: deleted,
      message: deleted ? 'Đã xóa khách hàng' : 'Không thể xóa khách hàng này.',
    );
  }

  Future<({bool success, String message})> assignBatchLocation({
    required WarehouseProvider warehouseProvider,
    required BatchProvider batchProvider,
    required BatchModel batch,
    required String locationId,
  }) async {
    final newLoc = warehouseProvider.findById(locationId);
    if (newLoc == null) {
      return (success: false, message: 'Vị trí kho không tồn tại.');
    }
    final moved = await warehouseProvider.assignBatchOnline(
      batchProvider: batchProvider,
      batchId: batch.id,
      locationId: newLoc.id,
    );
    if (!moved) {
      return (
        success: false,
        message: warehouseProvider.errorMessage ??
            'Vị trí không hoạt động hoặc không đủ sức chứa.',
      );
    }
    return (
      success: true,
      message: 'Đã chuyển lô ${batch.code} đến ${newLoc.code}.',
    );
  }
}
