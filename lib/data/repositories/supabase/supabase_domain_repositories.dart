import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_rice_warehouse/data/sync/business_sync_policy.dart';
import 'package:smart_rice_warehouse/data/repositories/supabase/supabase_json_repository.dart';
import 'package:smart_rice_warehouse/data/repositories/supabase/supabase_row_codec.dart';
import 'package:smart_rice_warehouse/logic/contracts/authentication_service.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/batch_location_writer.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/crud_repository.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/repository_exception.dart';
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

SupabaseJsonRepository<RiceCharacteristicModel> supabaseRiceCharacteristics({
  required SupabaseClient client,
  BusinessSyncPolicy? syncPolicy,
  Stream<AuthenticatedUser?>? authChanges,
}) =>
    SupabaseJsonRepository<RiceCharacteristicModel>(
      client: client,
      table: 'rice_characteristics',
      orderBy: 'name',
      syncPolicy: syncPolicy,
      authChanges: authChanges,
      decode: jsonDecoder(RiceCharacteristicModel.fromJson),
      encode: jsonEncoder((value) => value.toJson()),
    );

SupabaseJsonRepository<SupplierModel> supabaseSuppliers({
  required SupabaseClient client,
  BusinessSyncPolicy? syncPolicy,
  Stream<AuthenticatedUser?>? authChanges,
}) =>
    SupabaseJsonRepository<SupplierModel>(
      client: client,
      table: 'suppliers',
      orderBy: 'name',
      syncPolicy: syncPolicy,
      authChanges: authChanges,
      decode: jsonDecoder(SupplierModel.fromJson),
      encode: jsonEncoder((value) => value.toJson()),
    );

SupabaseJsonRepository<CustomerModel> supabaseCustomers({
  required SupabaseClient client,
  BusinessSyncPolicy? syncPolicy,
  Stream<AuthenticatedUser?>? authChanges,
}) =>
    SupabaseJsonRepository<CustomerModel>(
      client: client,
      table: 'customers',
      orderBy: 'name',
      syncPolicy: syncPolicy,
      authChanges: authChanges,
      decode: jsonDecoder(CustomerModel.fromJson),
      encode: jsonEncoder((value) => value.toJson()),
    );

SupabaseJsonRepository<ImportReceiptModel> supabaseImportReceipts({
  required SupabaseClient client,
  BusinessSyncPolicy? syncPolicy,
  Stream<AuthenticatedUser?>? authChanges,
}) =>
    SupabaseJsonRepository<ImportReceiptModel>(
      client: client,
      table: 'import_receipts',
      orderBy: 'date',
      syncPolicy: syncPolicy,
      authChanges: authChanges,
      readOnly: true,
      decode: jsonDecoder(ImportReceiptModel.fromJson),
      encode: jsonEncoder((value) => value.toJson()),
    );

SupabaseJsonRepository<DamageReportModel> supabaseDamageReports({
  required SupabaseClient client,
  BusinessSyncPolicy? syncPolicy,
  Stream<AuthenticatedUser?>? authChanges,
}) =>
    SupabaseJsonRepository<DamageReportModel>(
      client: client,
      table: 'damage_reports',
      orderBy: 'reported_at',
      syncPolicy: syncPolicy,
      authChanges: authChanges,
      readOnly: true,
      decode: jsonDecoder(DamageReportModel.fromJson),
      encode: jsonEncoder((value) => value.toJson()),
    );

SupabaseJsonRepository<RiceModel> supabaseRiceProducts({
  required SupabaseClient client,
  BusinessSyncPolicy? syncPolicy,
  Stream<AuthenticatedUser?>? authChanges,
}) =>
    SupabaseRiceProductRepository(
      client: client,
      syncPolicy: syncPolicy,
      authChanges: authChanges,
    );

class SupabaseRiceProductRepository extends SupabaseJsonRepository<RiceModel> {
  // Keep the client local for the async relation decoder closure.
  // ignore: use_super_parameters
  SupabaseRiceProductRepository({
    required SupabaseClient client,
    BusinessSyncPolicy? syncPolicy,
    Stream<AuthenticatedUser?>? authChanges,
  })  : _client = client,
        super(
          client: client,
          table: 'rice_products',
          orderBy: 'code',
          syncPolicy: syncPolicy,
          authChanges: authChanges,
          decode: (row) => _decodeRice(client, row),
          encode: (value) => value.toJson()..remove('characteristicIds'),
        );

  final SupabaseClient _client;

  static Future<RiceModel> _decodeRice(
    SupabaseClient client,
    Map<String, dynamic> row,
  ) async {
    final relations = await client
        .from('rice_product_characteristics')
        .select('characteristic_id')
        .eq('rice_id', row['id']);
    final json = SupabaseRowCodec.decode(row)
      ..['characteristicIds'] = relations
          .map((relation) => relation['characteristic_id'] as String)
          .toList(growable: false);
    return RiceModel.fromJson(json);
  }

  @override
  Future<void> create(String id, RiceModel value) => _save(id, value);

  @override
  Future<void> update(String id, RiceModel value) => _save(id, value);

  Future<void> _save(String id, RiceModel value) async {
    if (id.trim().isEmpty || id != value.id) {
      throw ArgumentError('Repository ID does not match model ID.');
    }
    try {
      await _client.rpc('save_rice_product', params: {
        'payload_product': value.toJson(),
      });
    } on PostgrestException catch (error) {
      throw _mapRiceError(error);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _client
          .rpc('delete_rice_product', params: {'target_id': id.trim()});
    } on PostgrestException catch (error) {
      throw _mapRiceError(error);
    }
  }

  RepositoryException _mapRiceError(PostgrestException error) =>
      RepositoryException(
        error.code == '42501'
            ? 'Chỉ quản trị viên mới được quản lý danh mục gạo.'
            : error.message,
        code: error.code,
        cause: error,
      );
}

class SupabaseBatchRepository
    implements CrudRepository<BatchModel>, BatchLocationWriter {
  SupabaseBatchRepository({
    required SupabaseClient client,
    BusinessSyncPolicy? syncPolicy,
    Stream<AuthenticatedUser?>? authChanges,
  })  : _client = client,
        _readRepository = SupabaseJsonRepository<BatchModel>(
          client: client,
          table: 'batches',
          orderBy: 'code',
          syncPolicy: syncPolicy,
          authChanges: authChanges,
          readOnly: true,
          decode: jsonDecoder(BatchModel.fromJson),
          encode: jsonEncoder((value) => value.toJson()),
        );

  final SupabaseClient _client;
  final SupabaseJsonRepository<BatchModel> _readRepository;

  @override
  Stream<List<BatchModel>> watchAll() => _readRepository.watchAll();

  @override
  Stream<BatchModel?> watchById(String id) => _readRepository.watchById(id);

  @override
  Future<List<BatchModel>> getAll() => _readRepository.getAll();

  @override
  Future<BatchModel?> getById(String id) => _readRepository.getById(id);

  @override
  Future<void> create(String id, BatchModel value) => _denyDirectStockWrite();

  @override
  Future<void> delete(String id) => _denyDirectStockWrite();

  @override
  Future<void> update(String id, BatchModel value) => moveBatch(
        batchId: id,
        locationId: value.warehouseLocationId ?? '',
        locationName: value.locationName ?? '',
      );

  @override
  Future<void> moveBatch({
    required String batchId,
    required String locationId,
    required String locationName,
  }) async {
    try {
      final row = await _client
          .from('batches')
          .update({
            'warehouse_location_id': locationId.isEmpty ? null : locationId,
            'location_name': locationName,
          })
          .eq('id', batchId.trim())
          .select('id')
          .maybeSingle();
      if (row == null) {
        throw const RepositoryException(
          'Lô không tồn tại hoặc vị trí không hợp lệ.',
          code: 'not-found-or-forbidden',
        );
      }
    } on PostgrestException catch (error) {
      throw RepositoryException(
        error.code == '42501'
            ? 'Bạn không có quyền chuyển vị trí lô hàng.'
            : error.message,
        code: error.code,
        cause: error,
      );
    }
  }

  Future<void> _denyDirectStockWrite() => throw const RepositoryException(
        'Không thể tạo hoặc xóa lô trực tiếp; hãy dùng giao dịch nhập kho.',
        code: 'transaction-required',
      );
}

SupabaseJsonRepository<WarehouseLocationModel> supabaseWarehouseLocations({
  required SupabaseClient client,
  BusinessSyncPolicy? syncPolicy,
  Stream<AuthenticatedUser?>? authChanges,
}) =>
    SupabaseJsonRepository<WarehouseLocationModel>(
      client: client,
      table: 'warehouse_locations_with_count',
      streamTable: 'warehouse_locations',
      writeTable: 'warehouse_locations',
      refreshSource: () => client
          .from('batches')
          .stream(primaryKey: ['id']).map<Object?>((_) => null),
      orderBy: 'code',
      syncPolicy: syncPolicy,
      authChanges: authChanges,
      decode: (row) async {
        final projected = row.containsKey('current_batch_count')
            ? row
            : await client
                .from('warehouse_locations_with_count')
                .select()
                .eq('id', row['id'])
                .single();
        return WarehouseLocationModel.fromJson(
            SupabaseRowCodec.decode(projected));
      },
      encode: (value) => value.toJson()..remove('currentBatchCount'),
    );

SupabaseJsonRepository<ExportReceiptModel> supabaseExportReceipts({
  required SupabaseClient client,
  BusinessSyncPolicy? syncPolicy,
  Stream<AuthenticatedUser?>? authChanges,
}) =>
    SupabaseJsonRepository<ExportReceiptModel>(
      client: client,
      table: 'export_receipts',
      orderBy: 'date',
      syncPolicy: syncPolicy,
      authChanges: authChanges,
      readOnly: true,
      decode: (row) async {
        final allocations = await client
            .from('export_receipt_allocations')
            .select()
            .eq('receipt_id', row['id'])
            .order('position');
        final json = SupabaseRowCodec.decode(row)
          ..['allocations'] = allocations
              .map((allocation) => SupabaseRowCodec.decode(allocation))
              .toList(growable: false);
        return ExportReceiptModel.fromJson(json);
      },
      encode: (value) => value.toJson()..remove('allocations'),
    );

SupabaseJsonRepository<InventoryCheckSession> supabaseInventoryChecks({
  required SupabaseClient client,
  BusinessSyncPolicy? syncPolicy,
  Stream<AuthenticatedUser?>? authChanges,
}) =>
    SupabaseJsonRepository<InventoryCheckSession>(
      client: client,
      table: 'inventory_checks',
      orderBy: 'created_at',
      syncPolicy: syncPolicy,
      authChanges: authChanges,
      readOnly: true,
      decode: (row) async {
        final items = await client
            .from('inventory_check_items')
            .select()
            .eq('check_id', row['id']);
        final json = SupabaseRowCodec.decode(row)
          ..['items'] = items
              .map((item) => SupabaseRowCodec.decode(item))
              .toList(growable: false);
        return InventoryCheckSession.fromJson(json);
      },
      encode: (value) => value.toJson()..remove('items'),
    );
