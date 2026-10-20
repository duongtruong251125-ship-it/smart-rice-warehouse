enum WarehouseSyncState {
  local,
  syncing,
  synced,
  error,
  unknown,
}

class SyncSourceSnapshot {
  const SyncSourceSnapshot({
    required this.usesFirestore,
    required this.isLoading,
    this.errorMessage,
  });

  final bool usesFirestore;
  final bool isLoading;
  final String? errorMessage;
}

class WarehouseSyncStatus {
  const WarehouseSyncStatus({
    required this.state,
    this.detailMessage,
  });

  final WarehouseSyncState state;
  final String? detailMessage;

  String get label {
    switch (state) {
      case WarehouseSyncState.local:
        return 'Cục bộ';
      case WarehouseSyncState.syncing:
        return 'Đang đồng bộ';
      case WarehouseSyncState.synced:
        return 'Đã đồng bộ';
      case WarehouseSyncState.error:
        return 'Lỗi đồng bộ';
      case WarehouseSyncState.unknown:
        return 'Chưa xác định';
    }
  }

  String get semanticDescription {
    final detail = detailMessage?.trim();
    if (detail != null && detail.isNotEmpty) {
      return 'Trạng thái đồng bộ: $label. $detail';
    }
    return 'Trạng thái đồng bộ: $label';
  }

  bool get hasError => state == WarehouseSyncState.error;
  bool get isSyncing => state == WarehouseSyncState.syncing;

  static WarehouseSyncStatus resolve({
    required List<SyncSourceSnapshot> sources,
    bool? backgroundSyncEnabled,
  }) {
    if (sources.isEmpty) {
      return const WarehouseSyncStatus(
        state: WarehouseSyncState.unknown,
        detailMessage: 'Chưa có nguồn dữ liệu',
      );
    }

    for (final source in sources) {
      final error = source.errorMessage?.trim();
      if (error != null && error.isNotEmpty) {
        return WarehouseSyncStatus(
          state: WarehouseSyncState.error,
          detailMessage: error,
        );
      }
    }

    if (sources.any((source) => source.isLoading)) {
      return const WarehouseSyncStatus(
        state: WarehouseSyncState.syncing,
        detailMessage: 'Đang đồng bộ dữ liệu kho',
      );
    }

    final anyCloud = sources.any((source) => source.usesFirestore);
    if (!anyCloud) {
      return const WarehouseSyncStatus(
        state: WarehouseSyncState.local,
        detailMessage: 'Đang dùng dữ liệu trên thiết bị',
      );
    }

    final allCloud = sources.every((source) => source.usesFirestore);
    if (allCloud) {
      return WarehouseSyncStatus(
        state: WarehouseSyncState.synced,
        detailMessage: backgroundSyncEnabled == false
            ? 'Dùng cloud; tạm dừng cập nhật khi ứng dụng ở nền'
            : 'Dữ liệu kho đã đồng bộ đám mây',
      );
    }

    return const WarehouseSyncStatus(
      state: WarehouseSyncState.unknown,
      detailMessage: 'Đồng bộ một phần nguồn dữ liệu',
    );
  }
}
