import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/models/inventory_snapshot_model.dart';
import 'package:smart_rice_warehouse/models/rice_model.dart';

class InventorySnapshotStore {
  InventorySnapshotStore({
    List<InventorySnapshotModel>? initial,
    this.onPersist,
  }) : _snapshots = List<InventorySnapshotModel>.from(initial ?? const []);

  final List<InventorySnapshotModel> _snapshots;
  final void Function(List<InventorySnapshotModel>)? onPersist;

  List<InventorySnapshotModel> get snapshots =>
      List<InventorySnapshotModel>.unmodifiable(_snapshots);

  void synchronize({
    required List<BatchModel> batches,
    required List<RiceModel> rices,
    DateTime? recordedAt,
  }) {
    final now = recordedAt ?? DateTime.now();
    final date = DateTime(now.year, now.month, now.day);
    final prices = {for (final rice in rices) rice.id: rice.purchasePrice};
    final today = DateTime(now.year, now.month, now.day);
    var totalQuantity = 0.0;
    var totalValue = 0.0;

    for (final batch in batches) {
      final expiry = DateTime(
        batch.expiryDate.year,
        batch.expiryDate.month,
        batch.expiryDate.day,
      );
      if (batch.quantity <= 0 ||
          batch.status == BatchStatus.expired ||
          expiry.isBefore(today)) {
        continue;
      }
      totalQuantity += batch.quantity;
      totalValue += batch.quantity * (prices[batch.riceId] ?? 0);
    }

    final existingIndex = _snapshots.indexWhere(
      (item) => _isSameDay(item.date, date),
    );
    final previous = existingIndex < 0 ? null : _snapshots[existingIndex];
    if (previous != null &&
        (previous.totalQuantity - totalQuantity).abs() < 0.0001 &&
        (previous.totalValue - totalValue).abs() < 0.01) {
      return;
    }

    final item = InventorySnapshotModel(
      id: previous?.id ?? now.microsecondsSinceEpoch,
      date: date,
      totalQuantity: totalQuantity,
      totalValue: totalValue,
      note: 'Snapshot tự động',
    );
    if (existingIndex < 0) {
      _snapshots.add(item);
    } else {
      _snapshots[existingIndex] = item;
    }
    _snapshots.sort((a, b) => a.date.compareTo(b.date));
    if (_snapshots.length > 90) {
      _snapshots.removeRange(0, _snapshots.length - 90);
    }
    onPersist?.call(snapshots);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
