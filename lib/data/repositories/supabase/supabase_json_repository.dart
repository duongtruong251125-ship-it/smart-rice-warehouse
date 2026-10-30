import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_rice_warehouse/data/sync/restarting_repository_stream.dart';
import 'package:smart_rice_warehouse/data/sync/business_sync_policy.dart';
import 'package:smart_rice_warehouse/data/repositories/supabase/supabase_row_codec.dart';
import 'package:smart_rice_warehouse/logic/contracts/authentication_service.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/crud_repository.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/repository_exception.dart';

typedef SupabaseRowDecoder<T> = FutureOr<T> Function(Map<String, dynamic> row);
typedef SupabaseRowEncoder<T> = Map<String, Object?> Function(T value);

/// Reusable Postgres repository for JSON-backed models. Read and stream
/// sources may differ from the write table for read-only SQL projections.
class SupabaseJsonRepository<T> implements CrudRepository<T> {
  SupabaseJsonRepository({
    required SupabaseClient client,
    required this.table,
    required this.decode,
    required this.encode,
    this.writeTable,
    this.streamTable,
    this.orderBy,
    this.idColumn = 'id',
    this.syncPolicy,
    this.authChanges,
    this.refreshSource,
    this.readOnly = false,
  }) : _client = client;

  final SupabaseClient _client;
  final String table;
  final String? writeTable;
  final String? streamTable;
  final String? orderBy;
  final String idColumn;
  final SupabaseRowDecoder<T> decode;
  final SupabaseRowEncoder<T> encode;
  final BusinessSyncPolicy? syncPolicy;
  final Stream<AuthenticatedUser?>? authChanges;
  final Stream<Object?> Function()? refreshSource;
  final bool readOnly;

  String get _streamSource => streamTable ?? table;
  String get _writeSource => writeTable ?? table;

  @override
  Stream<List<T>> watchAll() => restartingRepositoryStream<List<T>>(
        open: () {
          final query =
              _client.from(_streamSource).stream(primaryKey: [idColumn]);
          final Stream<List<Map<String, dynamic>>> source;
          if (orderBy == null) {
            source = query;
          } else {
            source = query.order(orderBy!);
          }
          final refresh = refreshSource;
          return (refresh == null
                  ? source
                  : reemitLatestOnRefresh(source, refresh()))
              .asyncMap(_decodeRows);
        },
        reconnect: authChanges,
        policyChanges: syncPolicy,
        shouldListen: () => syncPolicy?.shouldListen ?? true,
        mapError: _mapError,
      );

  @override
  Stream<T?> watchById(String id) => restartingRepositoryStream<T?>(
        open: () {
          final source = _client
              .from(_streamSource)
              .stream(primaryKey: [idColumn]).eq(idColumn, _validateId(id));
          final refresh = refreshSource;
          return (refresh == null
                  ? source
                  : reemitLatestOnRefresh(source, refresh()))
              .asyncMap(
                  (rows) async => rows.isEmpty ? null : decode(rows.first));
        },
        reconnect: authChanges,
        policyChanges: syncPolicy,
        shouldListen: () => syncPolicy?.shouldListen ?? true,
        mapError: _mapError,
      );

  @override
  Future<List<T>> getAll() async {
    try {
      final rows = orderBy == null
          ? await _client.from(table).select()
          : await _client.from(table).select().order(orderBy!);
      return await _decodeRows(List<Map<String, dynamic>>.from(rows));
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<T?> getById(String id) async {
    try {
      final row = await _client
          .from(table)
          .select()
          .eq(idColumn, _validateId(id))
          .maybeSingle();
      return row == null ? null : await decode(row);
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<void> create(String id, T value) async {
    _requireWritable();
    try {
      final row = _writeMap(value);
      if (row[idColumn]?.toString() != _validateId(id)) {
        throw ArgumentError('Repository ID does not match model ID.');
      }
      await _client.from(_writeSource).insert(row);
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<void> update(String id, T value) async {
    _requireWritable();
    try {
      final validatedId = _validateId(id);
      final row = _writeMap(value)
        ..remove(idColumn)
        ..remove('created_at')
        ..remove('updated_at');
      final updated = await _client
          .from(_writeSource)
          .update(row)
          .eq(idColumn, validatedId)
          .select(idColumn)
          .maybeSingle();
      if (updated == null) {
        throw const RepositoryException(
          'Bản ghi không tồn tại hoặc bạn không có quyền cập nhật.',
          code: 'not-found-or-forbidden',
        );
      }
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<void> delete(String id) async {
    _requireWritable();
    try {
      final deleted = await _client
          .from(_writeSource)
          .delete()
          .eq(idColumn, _validateId(id))
          .select(idColumn)
          .maybeSingle();
      if (deleted == null) {
        throw const RepositoryException(
          'Bản ghi không tồn tại hoặc bạn không có quyền xóa.',
          code: 'not-found-or-forbidden',
        );
      }
    } catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<T>> _decodeRows(List<Map<String, dynamic>> rows) =>
      Future.wait(rows.map((row) async => decode(row)));

  Map<String, Object?> _writeMap(T value) {
    final source = encode(value);
    return SupabaseRowCodec.encode(source)
      ..removeWhere((key, value) => value == null);
  }

  void _requireWritable() {
    if (readOnly) {
      throw const RepositoryException(
        'Bản chiếu dữ liệu này chỉ cho phép đọc.',
        code: 'read-only',
      );
    }
  }

  String _validateId(String id) {
    final normalized = id.trim();
    if (normalized.isEmpty || normalized.contains('/')) {
      throw ArgumentError.value(id, 'id', 'Invalid repository ID.');
    }
    return normalized;
  }

  Object _mapError(Object error) {
    if (error is RepositoryException) return error;
    if (error is PostgrestException) {
      final message = error.code == '42501'
          ? 'Bạn không có quyền truy cập dữ liệu này trên máy chủ.'
          : error.message;
      return RepositoryException(message, code: error.code, cause: error);
    }
    return RepositoryException(
      'Không thể truy cập dữ liệu trực tuyến: $error',
      cause: error,
    );
  }
}

/// Re-emits the most recent snapshot when a related table changes. This is
/// useful for read projections whose values depend on more than their source
/// table (Postgres views are not themselves usable as Realtime streams).
Stream<T> reemitLatestOnRefresh<T>(Stream<T> source, Stream<Object?> refresh) =>
    Stream<T>.multi((controller) {
      var hasValue = false;
      T? latest;
      final sourceSubscription = source.listen(
        (value) {
          latest = value;
          hasValue = true;
          controller.add(value);
        },
        onError: controller.addError,
      );
      final refreshSubscription = refresh.listen(
        (_) {
          if (hasValue) controller.add(latest as T);
        },
        onError: controller.addError,
      );
      controller.onCancel = () async {
        await sourceSubscription.cancel();
        await refreshSubscription.cancel();
      };
    });

SupabaseRowEncoder<T> jsonEncoder<T>(Map<String, Object?> Function(T) toJson) =>
    toJson;

SupabaseRowDecoder<T> jsonDecoder<T>(
        T Function(Map<String, dynamic>) fromJson) =>
    (row) => fromJson(SupabaseRowCodec.decode(row));
