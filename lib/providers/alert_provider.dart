import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/core/utils/date_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/models/alert_model.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/models/rice_model.dart';

class AlertProvider extends ChangeNotifier {
  AlertProvider();

  List<AlertModel> _alerts = <AlertModel>[];
  final Set<String> _readAlertIds = <String>{};

  List<AlertModel> get alerts => List<AlertModel>.unmodifiable(_alerts);

  int get unreadCount => _alerts.where((a) => !a.isRead).length;

  int get lowStockCount =>
      _alerts.where((a) => a.type == AlertType.lowStock).length;

  int get expiringCount =>
      _alerts.where((a) => a.type == AlertType.expiringSoon).length;

  int get expiredCount =>
      _alerts.where((a) => a.type == AlertType.expired).length;

  int get criticalCount =>
      _alerts.where((a) => a.severity == AlertSeverity.critical).length;

  List<AlertModel> get criticalAlerts => _alerts
      .where((a) => a.severity == AlertSeverity.critical)
      .toList(growable: false);

  void markAsRead(String alertId) {
    _readAlertIds.add(alertId);
    final index = _alerts.indexWhere((a) => a.id == alertId);
    if (index != -1) {
      _alerts[index] = _alerts[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (final alert in _alerts) {
      _readAlertIds.add(alert.id);
    }
    _alerts = _alerts.map((a) => a.copyWith(isRead: true)).toList();
    notifyListeners();
  }

  /// Quét và phát hiện cảnh báo tồn kho và hạn dùng dựa trên dữ liệu hiện tại
  void scanAlerts({
    required List<RiceModel> rices,
    required List<BatchModel> batches,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final newAlerts = <AlertModel>[];

    // 1. Quét cảnh báo tồn kho thấp (Low Stock Detection)
    for (final rice in rices) {
      if (!rice.isActive) continue;

      // Tính tổng tồn kho khả dụng của loại gạo (các lô còn hạn và quantity > 0)
      final availableStock = batches.where((b) {
        if (b.riceId != rice.id || b.quantity <= 0) return false;
        if (b.status == BatchStatus.expired) return false;
        final expiry = DateTime(
          b.expiryDate.year,
          b.expiryDate.month,
          b.expiryDate.day,
        );
        return !expiry.isBefore(today);
      }).fold(0.0, (sum, b) => sum + b.quantity);

      if (availableStock <= rice.minimumStock) {
        final alertId = 'alert-low-stock-${rice.id}';
        final isCritical = availableStock <= 0;

        newAlerts.add(
          AlertModel(
            id: alertId,
            type: AlertType.lowStock,
            riceId: rice.id,
            riceName: rice.name,
            title: isCritical
                ? 'Hết hàng: ${rice.name}'
                : 'Tồn kho thấp: ${rice.name}',
            message: isCritical
                ? 'Đã hết hàng hoàn toàn trong kho. Cần nhập gấp!'
                : 'Tồn kho khả dụng hiện tại (${NumberFormatter.quantity(availableStock)} ${rice.unit}) '
                    'đạt hoặc dưới mức tối thiểu (${NumberFormatter.quantity(rice.minimumStock)} ${rice.unit}).',
            severity:
                isCritical ? AlertSeverity.critical : AlertSeverity.warning,
            createdAt: now,
            isRead: _readAlertIds.contains(alertId),
          ),
        );
      }
    }

    // 2. Quét cảnh báo hạn sử dụng (Expiry Detection)
    // Quy tắc:
    // > 30 ngày: normal (không tạo cảnh báo)
    // 8–30 ngày: warning (expiringSoon)
    // 1–7 ngày: critical (expiringSoon)
    // expiryDate < today: expired (critical)
    for (final batch in batches) {
      if (batch.quantity <= 0) continue;

      final expiry = DateTime(
        batch.expiryDate.year,
        batch.expiryDate.month,
        batch.expiryDate.day,
      );
      final daysUntilExpiry = expiry.difference(today).inDays;

      if (daysUntilExpiry < 0 || batch.status == BatchStatus.expired) {
        // Đã hết hạn
        final alertId = 'alert-expired-${batch.id}';
        newAlerts.add(
          AlertModel(
            id: alertId,
            type: AlertType.expired,
            riceId: batch.riceId,
            riceName: batch.riceName,
            batchId: batch.id,
            batchCode: batch.code,
            title: 'Lô đã hết hạn: ${batch.code}',
            message: 'Lô ${batch.code} (${batch.riceName}, còn ${NumberFormatter.quantity(batch.quantity)} kg) '
                'đã hết hạn vào ${DateFormatter.ddMMyyyy(batch.expiryDate)}. Tuyệt đối không xuất hàng lô này!',
            severity: AlertSeverity.critical,
            createdAt: now,
            isRead: _readAlertIds.contains(alertId),
          ),
        );
      } else if (daysUntilExpiry <= 7) {
        // Cận hạn khẩn cấp (1 - 7 ngày)
        final alertId = 'alert-expiring-${batch.id}';
        newAlerts.add(
          AlertModel(
            id: alertId,
            type: AlertType.expiringSoon,
            riceId: batch.riceId,
            riceName: batch.riceName,
            batchId: batch.id,
            batchCode: batch.code,
            title: 'Lô sắp hết hạn khẩn cấp: ${batch.code}',
            message: 'Lô ${batch.code} (${batch.riceName}, tồn ${NumberFormatter.quantity(batch.quantity)} kg) '
                'chỉ còn $daysUntilExpiry ngày là hết hạn (${DateFormatter.ddMMyyyy(batch.expiryDate)}). Ưu tiên xuất FEFO ngay!',
            severity: AlertSeverity.critical,
            createdAt: now,
            isRead: _readAlertIds.contains(alertId),
          ),
        );
      } else if (daysUntilExpiry <= 30) {
        // Cận hạn cảnh báo (8 - 30 ngày)
        final alertId = 'alert-expiring-${batch.id}';
        newAlerts.add(
          AlertModel(
            id: alertId,
            type: AlertType.expiringSoon,
            riceId: batch.riceId,
            riceName: batch.riceName,
            batchId: batch.id,
            batchCode: batch.code,
            title: 'Lô sắp hết hạn: ${batch.code}',
            message: 'Lô ${batch.code} (${batch.riceName}, tồn ${NumberFormatter.quantity(batch.quantity)} kg) '
                'còn $daysUntilExpiry ngày đến hạn (${DateFormatter.ddMMyyyy(batch.expiryDate)}).',
            severity: AlertSeverity.warning,
            createdAt: now,
            isRead: _readAlertIds.contains(alertId),
          ),
        );
      }
      // > 30 ngày: normal, không tạo alert
    }

    // Sắp xếp: critical lên trước -> warning -> info; cùng mức thì sắp theo thời gian
    newAlerts.sort((a, b) {
      final severityOrder = _severityWeight(b.severity).compareTo(
        _severityWeight(a.severity),
      );
      if (severityOrder != 0) return severityOrder;
      return b.createdAt.compareTo(a.createdAt);
    });

    _alerts = newAlerts;
    notifyListeners();
  }

  int _severityWeight(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return 3;
      case AlertSeverity.warning:
        return 2;
      case AlertSeverity.info:
        return 1;
    }
  }
}
