import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/repository_exception.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/user_profile_repository.dart';
import 'package:smart_rice_warehouse/logic/models/user_model.dart';
import 'package:smart_rice_warehouse/data/repositories/supabase/supabase_user_profile_codec.dart';

/// Supabase profile adapter. Profile creation is handled by the auth.users
/// trigger; role changes are restricted to a database RPC.
class SupabaseUserProfileRepository implements UserProfileRepository {
  SupabaseUserProfileRepository({required SupabaseClient client})
      : _client = client;

  final SupabaseClient _client;

  @override
  Stream<List<UserModel>> watchAll() => Stream<List<UserModel>>.multi(
        (controller) {
          StreamSubscription<List<UserModel>>? realtimeSubscription;
          var cancelled = false;

          Future<void> emitInitialSnapshot() async {
            try {
              controller.add(await _getAll());
            } catch (error, stackTrace) {
              if (!cancelled) controller.addError(error, stackTrace);
            }

            if (cancelled) return;
            final snapshots = _client
                .from('profiles')
                .stream(primaryKey: ['id'])
                .order('display_name')
                .map((rows) => rows.map(_fromRow).toList(growable: false));
            realtimeSubscription = snapshots.listen(
              controller.add,
              onError: controller.addError,
            );
          }

          unawaited(emitInitialSnapshot());
          controller.onCancel = () async {
            cancelled = true;
            await realtimeSubscription?.cancel();
          };
        },
      );

  @override
  Stream<UserModel?> watchById(String uid) => _client
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', _validateUid(uid))
      .limit(1)
      .map((rows) => rows.isEmpty ? null : _fromRow(rows.first));

  Future<List<UserModel>> _getAll() async {
    try {
      final rows =
          await _client.from('profiles').select().order('display_name');
      return rows.map((row) => _fromRow(row)).toList(growable: false);
    } on PostgrestException catch (error) {
      throw _repositoryError(error);
    }
  }

  @override
  Future<UserModel?> getById(String uid) async {
    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', _validateUid(uid))
          .maybeSingle();
      return row == null ? null : _fromRow(row);
    } on PostgrestException catch (error) {
      throw _repositoryError(error);
    }
  }

  @override
  Future<void> createPendingProfile({
    required String uid,
    required String email,
    required String displayName,
  }) async {
    // The database trigger creates the disabled staff profile atomically with
    // auth.users. A signup may have no client session while email confirmation
    // is pending, so querying the RLS-protected profile here would fail.
    _validateUid(uid);
    if (email.trim().isEmpty) throw ArgumentError.value(email, 'email');
    _validDisplayName(displayName);
  }

  @override
  Future<void> updateDisplayName({
    required String uid,
    required String displayName,
  }) async {
    try {
      await _client
          .from('profiles')
          .update({'display_name': _validDisplayName(displayName)}).eq(
              'id', _validateUid(uid));
    } on PostgrestException catch (error) {
      throw _repositoryError(error);
    }
  }

  @override
  Future<void> updateAccess({
    required String uid,
    required String role,
    required bool isActive,
  }) async {
    if (role != 'admin' && role != 'staff') {
      throw ArgumentError.value(role, 'role', 'Role must be admin or staff.');
    }
    try {
      await _client.rpc('admin_update_profile_access', params: {
        'target_user_id': _validateUid(uid),
        'target_role': role,
        'target_is_active': isActive,
      });
    } on PostgrestException catch (error) {
      throw _repositoryError(error);
    }
  }

  @override
  Future<bool> confirmEmail(String uid) async {
    try {
      final response = await _client.functions.invoke(
        'admin-confirm-email',
        body: {'userId': _validateUid(uid)},
      );
      final data = response.data;
      if (data is! Map<String, dynamic> || data['alreadyConfirmed'] is! bool) {
        throw const RepositoryException(
          'Máy chủ trả về kết quả xác minh không hợp lệ.',
          code: 'invalid-confirmation-response',
        );
      }
      return data['alreadyConfirmed'] as bool;
    } on FunctionException catch (error) {
      final message = switch (error.status) {
        401 => 'Phiên đăng nhập hết hạn. Hãy đăng nhập lại.',
        403 => 'Chỉ quản trị viên đang hoạt động mới được xác minh email.',
        404 => 'Không tìm thấy tài khoản cần xác minh.',
        409 => 'Không thể xác minh email của chính tài khoản đang đăng nhập.',
        400 => 'Tài khoản cần xác minh không hợp lệ.',
        _ => 'Không thể xác minh email trên máy chủ. Vui lòng thử lại.',
      };
      throw RepositoryException(
        message,
        code: error.status.toString(),
        cause: error,
      );
    } on PostgrestException catch (error) {
      throw _repositoryError(error);
    }
  }

  UserModel _fromRow(Map<String, dynamic> row) =>
      SupabaseUserProfileCodec.fromRow(row);

  String _validateUid(String uid) {
    final normalized = uid.trim();
    if (normalized.isEmpty) throw ArgumentError.value(uid, 'uid');
    return normalized;
  }

  String _validDisplayName(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.length > 100) {
      throw ArgumentError.value(value, 'displayName');
    }
    return normalized;
  }

  RepositoryException _repositoryError(PostgrestException error) {
    final permissionDenied = error.code == '42501';
    return RepositoryException(
      permissionDenied
          ? 'Bạn không có quyền cập nhật thông tin này trên máy chủ.'
          : error.message,
      code: error.code,
      cause: error,
    );
  }
}
