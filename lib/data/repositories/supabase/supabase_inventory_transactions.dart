import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_rice_warehouse/logic/contracts/inventory_transactions.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/repository_exception.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/damage_report_model.dart';
import 'package:smart_rice_warehouse/logic/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/inventory_check_model.dart';

/// Supabase transaction adapter. Actor IDs are derived from auth.uid() inside
/// PostgreSQL rather than trusted from the client payload.
class SupabaseInventoryTransactions implements InventoryTransactions {
  SupabaseInventoryTransactions({required SupabaseClient client})
      : _client = client;

  final SupabaseClient _client;

  @override
  Future<void> confirmImportReceipt({
    required ImportReceiptModel receipt,
    required BatchModel batchToCreateOrUpdate,
    required String performedBy,
  }) =>
      _call('confirm_import_receipt', {
        'payload_receipt': receipt.toJson(),
        'payload_batch': batchToCreateOrUpdate.toJson(),
      });

  @override
  Future<void> confirmExportReceipt({
    required ExportReceiptModel receipt,
    required String performedBy,
  }) =>
      _call('confirm_export_receipt', {
        'payload_receipt': receipt.toJson(),
      });

  @override
  Future<void> confirmDamageReport({
    required DamageReportModel report,
    required String performedBy,
  }) =>
      _call('confirm_damage_report', {'payload_report': report.toJson()});

  @override
  Future<void> completeInventoryCheck({
    required InventoryCheckSession session,
    required String performedBy,
  }) =>
      _call('complete_inventory_check', {'payload_session': session.toJson()});

  Future<void> _call(String function, Map<String, Object?> parameters) async {
    try {
      await _client.rpc(function, params: parameters);
    } on PostgrestException catch (error) {
      throw RepositoryException(
        _messageFor(error),
        code: error.code,
        cause: error,
      );
    } catch (error) {
      throw RepositoryException(
        'Không thể xác nhận giao dịch trên máy chủ.',
        code: 'transaction-failed',
        cause: error,
      );
    }
  }

  String _messageFor(PostgrestException error) {
    switch (error.code) {
      case '42501':
        return 'Tài khoản chưa được cấp quyền hoặc đã bị khóa.';
      case '23505':
        return 'Mã chứng từ hoặc mã lô đã tồn tại.';
      case '23503':
        return 'Gạo, khách hàng hoặc nhà cung cấp không còn hoạt động.';
      case '40001':
        return 'Tồn kho đã thay đổi sau khi kiểm đếm. Vui lòng tải lại.';
      case '22023':
        return 'Thông tin giao dịch không hợp lệ: ${error.message}';
      default:
        return 'Không thể xác nhận giao dịch: ${error.message}';
    }
  }
}
