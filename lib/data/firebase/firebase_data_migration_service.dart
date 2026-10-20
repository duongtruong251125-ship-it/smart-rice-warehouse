import 'package:cloud_functions/cloud_functions.dart';
import 'package:smart_rice_warehouse/data/local/app_database.dart';
import 'package:smart_rice_warehouse/logic/contracts/authentication_service.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/user_profile_repository.dart';

enum MigrationStatus { success, partial, failure }

class MigrationResult {
  const MigrationResult(
      {required this.status,
      required this.message,
      this.migratedCounts = const {},
      this.errors = const {}});
  final MigrationStatus status;
  final String message;
  final Map<String, int> migratedCounts;
  final Map<String, String> errors;
  bool get isSuccess => status == MigrationStatus.success;
  bool get isPartial => status == MigrationStatus.partial;
  bool get isFailure => status == MigrationStatus.failure;
}

typedef MigrationCallable = Future<Map<String, dynamic>> Function(
    Map<String, dynamic> payload);

/// Explicit admin-only import of the legacy SQLite dataset approved as real.
/// Never seeds data, writes directly to Firestore, or runs on Auth events.
class FirebaseDataMigrationService {
  FirebaseDataMigrationService(
      {required this.authentication,
      required this.profiles,
      required this.loadLegacySnapshot,
      MigrationCallable? invoke})
      : _invoke = invoke ??
            ((payload) async {
              final result =
                  await FirebaseFunctions.instanceFor(region: 'us-central1')
                      .httpsCallable('migrateLegacyWarehouse')
                      .call<dynamic>(payload);
              return Map<String, dynamic>.from(result.data as Map);
            });

  final AuthenticationService authentication;
  final UserProfileRepository profiles;
  final Future<AppSnapshot> Function() loadLegacySnapshot;
  final MigrationCallable _invoke;

  static Map<String, dynamic> manifest(AppSnapshot snapshot) {
    final records = <Map<String, dynamic>>[];
    Object? encode(Object? value, [String? key]) {
      const dates = {
        'date',
        'createdAt',
        'updatedAt',
        'importDate',
        'manufactureDate',
        'expiryDate',
        'completedAt'
      };
      if (value is String && dates.contains(key)) {
        return DateTime.parse(value).toUtc().toIso8601String();
      }
      if (value is Map) {
        return value
            .map((k, v) => MapEntry(k.toString(), encode(v, k.toString())));
      }
      if (value is List) return value.map((v) => encode(v)).toList();
      return value;
    }

    void add(String collection, Object id, Map<String, Object?> json) {
      final data = Map<String, Object?>.from(json)
        ..remove('id')
        ..remove('imagePath')
        ..remove('createdBy');
      records.add({
        'collection': collection,
        'id': id.toString(),
        'data': encode(data)
      });
    }

    for (final item in snapshot.characteristics ?? []) {
      add('rice_characteristics', item.id, item.toJson());
    }
    for (final item in snapshot.rices ?? []) {
      add('rice_products', item.id, item.toJson());
    }
    for (final item in snapshot.suppliers ?? []) {
      add('suppliers', item.id, item.toJson());
    }
    for (final item in snapshot.customers ?? []) {
      add('customers', item.id, item.toJson());
    }
    for (final item in snapshot.locations ?? []) {
      add('warehouse_locations', item.id, item.toJson());
    }
    for (final item in snapshot.batches ?? []) {
      add('batches', item.id, item.toJson());
    }
    for (final item in snapshot.importReceipts ?? []) {
      add('import_receipts', item.id, item.toJson());
    }
    for (final item in snapshot.exportReceipts ?? []) {
      add('export_receipts', item.id, item.toJson());
    }
    for (final item in snapshot.damageReports ?? []) {
      add('damage_reports', item.id, item.toJson());
    }
    for (final item in snapshot.inventoryChecks ?? []) {
      add('inventory_checks', item.id, item.toJson());
    }
    for (final item in snapshot.snapshots) {
      add('inventory_snapshots', item.id, item.toJson());
    }
    records.sort((a, b) => '${a['collection']}/${a['id']}'
        .compareTo('${b['collection']}/${b['id']}'));
    return {'approvedLegacyData': true, 'records': records};
  }

  Future<MigrationResult> runMigration() async {
    var acknowledged = 0;
    try {
      final user = authentication.currentUser;
      if (user == null) throw StateError('Vui lòng đăng nhập.');
      final profile = await profiles.getById(user.uid);
      if (profile?.id != user.uid ||
          profile?.role != 'admin' ||
          profile?.isActive != true ||
          authentication.currentUser?.uid != user.uid) {
        throw StateError('Chỉ admin đang hoạt động được chuyển dữ liệu cũ.');
      }
      final payload = manifest(await loadLegacySnapshot());
      final count = (payload['records'] as List).length;
      if (count == 0) {
        return const MigrationResult(
            status: MigrationStatus.success,
            message: 'Không có dữ liệu SQLite cũ để chuyển.');
      }
      for (var step = 0; step <= count; step++) {
        if (authentication.currentUser?.uid != user.uid) {
          throw StateError('Phiên đăng nhập đã thay đổi.');
        }
        final result = await _invoke(payload);
        final cursor = result['nextIndex'];
        if (cursor is! int || cursor < acknowledged || cursor > count) {
          throw StateError('Máy chủ trả trạng thái migration không hợp lệ.');
        }
        if (result['status'] == 'completed' && cursor == count) {
          return MigrationResult(
              status: MigrationStatus.success,
              message:
                  'Đã chuyển dữ liệu cũ thành dữ liệu thật. Bản ghi cloud hiện có được giữ nguyên.',
              migratedCounts: {
                'inserted': (result['inserted'] as num).toInt(),
                'skipped': (result['skipped'] as num).toInt()
              });
        }
        if (cursor <= acknowledged) {
          throw StateError('Migration không tiến triển.');
        }
        acknowledged = cursor;
      }
      throw StateError('Migration vượt số bước cho phép.');
    } catch (error) {
      return MigrationResult(
          status: acknowledged > 0
              ? MigrationStatus.partial
              : MigrationStatus.failure,
          message:
              'Chưa hoàn tất chuyển dữ liệu cũ: $error. Có thể thử lại; không ghi đè cloud.',
          migratedCounts: {'acknowledged': acknowledged},
          errors: {'migration': error.toString()});
    }
  }
}
